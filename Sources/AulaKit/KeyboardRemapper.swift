import Foundation
import CoreGraphics
import AppKit
import ApplicationServices
import IOKit.hid

public enum AulaPermissions {
    public static var accessibility: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    public static func requestAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public static var inputMonitoring: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    @discardableResult
    public static func requestInputMonitoring() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    public static var canPostEvents: Bool {
        CGPreflightPostEventAccess()
    }

    public static func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    public static func openInputMonitoringSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    public static func openBluetoothSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")
    }

    private static func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}

/// Per-device keyboard remapping and macro playback at the macOS event layer.
///
/// Uses the undocumented CGEvent field 87 (the IORegistry sender ID) to tell
/// which physical keyboard produced an event. Synthetic events posted by this
/// class carry a marker in `eventSourceUserData`, so they are never re-processed.
/// Requires Accessibility permission; Input Monitoring is needed for HID discovery.
public final class KeyboardRemapper {
    public enum RemapError: LocalizedError {
        case noAccessibility
        case tapCreationFailed

        public var errorDescription: String? {
            switch self {
            case .noAccessibility:
                return "Accessibility permission is required to remap keys. Enable AULA Control in System Settings → Privacy & Security → Accessibility."
            case .tapCreationFailed:
                return "Could not create the keyboard event tap. Check Accessibility and Input Monitoring permissions."
            }
        }
    }

    public private(set) var isRunning = false
    public var log: ((String) -> Void)?
    /// Called for every hardware event with the product name of its sender.
    public var onEventSource: ((String) -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let lock = NSLock()
    private var rulesByUsage: [UInt8: KeyAction] = [:]
    private var macros: [Macro] = []
    private var onlyThisKeyboard = true
    private var senderCache: [UInt64: Bool] = [:]
    private var senderNameCache: [UInt64: String] = [:]
    private var modifierKeysDown: Set<CGKeyCode> = []
    private var macroQueue = DispatchQueue(label: "com.aulacontrol.macros")

    private let syntheticMarker: Int64 = 0x4155_4C41 // "AULA"
    private static let senderField = CGEventField(rawValue: 87)!

    public init() {}

    deinit {
        stop()
    }

    public func update(rules: KeyRemapMap, macros: [Macro], onlyThisKeyboard: Bool) {
        var byUsage: [UInt8: KeyAction] = [:]
        let layout = KeyLayout.f108Pro
        for (name, action) in rules {
            guard let key = layout.key(named: name), !action.isNoOp else { continue }
            byUsage[key.usage] = action
        }
        lock.lock()
        self.rulesByUsage = byUsage
        self.macros = macros
        self.onlyThisKeyboard = onlyThisKeyboard
        self.senderCache.removeAll()
        self.senderNameCache.removeAll()
        lock.unlock()
    }

    @discardableResult
    public func start() throws -> Bool {
        if isRunning { return true }
        guard AulaPermissions.accessibility else { throw RemapError.noAccessibility }

        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { proxy, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let remapper = Unmanaged<KeyboardRemapper>.fromOpaque(refcon).takeUnretainedValue()
                return remapper.handle(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw RemapError.tapCreationFailed
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        log?("Event tap started")
        return true
    }

    public func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            }
            CFMachPortInvalidate(tap)
        }
        tap = nil
        runLoopSource = nil
        isRunning = false
        modifierKeysDown.removeAll()
        log?("Event tap stopped")
    }

    // MARK: - Event handling

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        // Never process our own synthetic events.
        if event.getIntegerValueField(.eventSourceUserData) == syntheticMarker {
            return Unmanaged.passUnretained(event)
        }

        lock.lock()
        let onlyAULA = onlyThisKeyboard
        let rules = rulesByUsage
        lock.unlock()

        reportSource(for: event)

        if onlyAULA && !isAULA(event) {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        switch type {
        case .keyDown, .keyUp:
            guard let usage = KeyLayout.usage(forMacKeyCode: keyCode),
                  let action = rules[usage] else {
                return Unmanaged.passUnretained(event)
            }
            return apply(action, to: event, usage: usage, type: type, keyCode: keyCode)

        case .flagsChanged:
            guard let usage = modifierUsage(for: keyCode),
                  let action = rules[usage] else {
                return Unmanaged.passUnretained(event)
            }
            lock.lock()
            let isDown: Bool
            if modifierKeysDown.contains(keyCode) {
                modifierKeysDown.remove(keyCode)
                isDown = false
            } else {
                modifierKeysDown.insert(keyCode)
                isDown = true
            }
            lock.unlock()
            return applyToModifier(action, event: event, isDown: isDown)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func apply(
        _ action: KeyAction, to event: CGEvent, usage: UInt8, type: CGEventType, keyCode: CGKeyCode
    ) -> Unmanaged<CGEvent>? {
        let down = type == .keyDown

        switch action {
        case .none, .special, .mouse:
            return Unmanaged.passUnretained(event)

        case .disabled:
            return nil

        case .key(let target, let modifiers):
            guard let targetCode = KeyLayout.macKeyCode(forUsage: target) else {
                return Unmanaged.passUnretained(event)
            }
            event.setIntegerValueField(.keyboardEventKeycode, value: Int64(targetCode))
            let flags = cgFlags(for: modifiers)
            if down {
                event.flags = event.flags.union(flags)
            } else {
                event.flags = event.flags.subtracting(flags)
            }
            return Unmanaged.passUnretained(event)

        case .modifier(let bits):
            // The physical key is a normal key (e.g. Caps Lock) but should act
            // as a held modifier. Emit a flagsChanged event around it.
            postModifier(bits: bits, down: down)
            return nil

        case .consumer(let consumer):
            if down && !isRepeat(event) {
                postConsumer(consumer, down: true)
            } else if !down {
                postConsumer(consumer, down: false)
            }
            return nil

        case .macro(let index, _, _):
            if down && !isRepeat(event) {
                playMacro(index: index)
            }
            return nil
        }
    }

    private func applyToModifier(
        _ action: KeyAction, event: CGEvent, isDown: Bool
    ) -> Unmanaged<CGEvent>? {
        // Modifier keys arrive as flagsChanged. If the user remaps them, we
        // translate the press/release into the requested action.
        switch action {
        case .disabled:
            return nil
        case .key(let target, let modifiers):
            guard let code = KeyLayout.macKeyCode(forUsage: target) else {
                return Unmanaged.passUnretained(event)
            }
            postKey(code: code, down: isDown, flags: cgFlags(for: modifiers))
            return nil
        case .consumer(let consumer):
            postConsumer(consumer, down: isDown)
            return nil
        case .macro(let index, _, _):
            if isDown { playMacro(index: index) }
            return nil
        case .modifier(let bits):
            // Swapping one modifier for another.
            postModifier(bits: bits, down: isDown)
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func isRepeat(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.keyboardEventAutorepeat) != 0
    }

    private func modifierUsage(for keyCode: CGKeyCode) -> UInt8? {
        switch keyCode {
        case 56: return 0xE1
        case 60: return 0xE5
        case 59: return 0xE0
        case 62: return 0xE4
        case 58: return 0xE2
        case 61: return 0xE6
        case 55: return 0xE3
        case 54: return 0xE7
        default: return nil
        }
    }

    private func isAULA(_ event: CGEvent) -> Bool {
        let raw = event.getIntegerValueField(Self.senderField)
        let sender = UInt64(bitPattern: raw)
        guard sender != 0 else { return false }

        lock.lock()
        if let cached = senderCache[sender] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let result = AulaDiscovery.isAulaRegistryID(sender)
        lock.lock()
        senderCache[sender] = result
        lock.unlock()
        return result
    }

    private func productName(for sender: UInt64) -> String? {
        lock.lock()
        if let cached = senderNameCache[sender] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let name = AulaDiscovery.productName(forRegistryID: sender)
        lock.lock()
        senderNameCache[sender] = name ?? "Unknown HID device"
        lock.unlock()
        return name
    }

    private func reportSource(for event: CGEvent) {
        guard let onEventSource else { return }
        let raw = event.getIntegerValueField(Self.senderField)
        let sender = UInt64(bitPattern: raw)
        guard sender != 0 else { return }
        if let name = productName(for: sender) {
            onEventSource(name)
        }
    }

    private func cgFlags(for bits: UInt8) -> CGEventFlags {
        var flags: CGEventFlags = []
        if bits & (ModifierBits.leftControl | ModifierBits.rightControl) != 0 { flags.insert(.maskControl) }
        if bits & (ModifierBits.leftShift | ModifierBits.rightShift) != 0 { flags.insert(.maskShift) }
        if bits & (ModifierBits.leftOption | ModifierBits.rightOption) != 0 { flags.insert(.maskAlternate) }
        if bits & (ModifierBits.leftCommand | ModifierBits.rightCommand) != 0 { flags.insert(.maskCommand) }
        return flags
    }

    private func modifierKeyCode(for bits: UInt8) -> CGKeyCode? {
        if bits & ModifierBits.rightCommand != 0 { return 54 }
        if bits & ModifierBits.leftCommand != 0 { return 55 }
        if bits & ModifierBits.rightShift != 0 { return 60 }
        if bits & ModifierBits.leftShift != 0 { return 56 }
        if bits & ModifierBits.rightOption != 0 { return 61 }
        if bits & ModifierBits.leftOption != 0 { return 58 }
        if bits & ModifierBits.rightControl != 0 { return 62 }
        if bits & ModifierBits.leftControl != 0 { return 59 }
        return nil
    }

    private func postModifier(bits: UInt8, down: Bool) {
        guard let code = modifierKeyCode(for: bits) else { return }
        let flags = cgFlags(for: bits)
        guard let event = CGEvent(source: nil) else { return }
        event.type = .flagsChanged
        event.setIntegerValueField(.keyboardEventKeycode, value: Int64(code))
        event.flags = down ? event.flags.union(flags) : event.flags.subtracting(flags)
        event.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
        event.post(tap: .cghidEventTap)
    }

    private func postKey(code: CGKeyCode, down: Bool, flags: CGEventFlags = []) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down) else { return }
        event.flags = flags
        event.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
        event.post(tap: .cghidEventTap)
    }

    private func postConsumer(_ usage: UInt16, down: Bool) {
        let nxKey: Int
        switch usage {
        case 0xE9: nxKey = 0      // NX_KEYTYPE_SOUND_UP
        case 0xEA: nxKey = 1      // NX_KEYTYPE_SOUND_DOWN
        case 0xE2: nxKey = 7      // NX_KEYTYPE_MUTE
        case 0xCD: nxKey = 16     // NX_KEYTYPE_PLAY
        case 0xB5: nxKey = 17     // NX_KEYTYPE_NEXT
        case 0xB6: nxKey = 18     // NX_KEYTYPE_PREVIOUS
        default: return
        }
        let flags = down ? 0xA : 0xB
        let data1 = (nxKey << 16) | (flags << 8)
        guard let event = NSEvent.otherEvent(
            with: .systemDefined, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0, context: nil, subtype: 8, data1: data1, data2: -1
        )?.cgEvent else { return }
        event.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
        event.post(tap: .cghidEventTap)
    }

    private func playMacro(index: UInt8) {
        lock.lock()
        guard Int(index) < macros.count else {
            lock.unlock()
            return
        }
        let macro = macros[Int(index)]
        lock.unlock()

        let repeats: Int
        switch macro.playMode {
        case .once, .toggle, .hold:
            repeats = 1
        case .repeatCount:
            repeats = max(1, macro.repeatCount)
        }
        let steps = macro.steps

        macroQueue.async { [weak self] in
            guard let self else { return }
            for _ in 0..<repeats {
                for step in steps {
                    switch step {
                    case .key(let usage, let down):
                        guard let code = KeyLayout.macKeyCode(forUsage: usage) else { continue }
                        self.postKey(code: code, down: down)
                        Thread.sleep(forTimeInterval: 0.005)
                    case .mouse(let button, let down):
                        self.postMouse(button: button, down: down)
                        Thread.sleep(forTimeInterval: 0.005)
                    case .delay(let ms):
                        Thread.sleep(forTimeInterval: Double(max(10, ms)) / 1000)
                    }
                }
            }
        }
    }

    private func postMouse(button: UInt8, down: Bool) {
        let location = CGEvent(source: nil)?.location ?? .zero
        let type: CGEventType
        let mouseButton: CGMouseButton
        switch button {
        case 1: type = down ? .leftMouseDown : .leftMouseUp; mouseButton = .left
        case 2: type = down ? .rightMouseDown : .rightMouseUp; mouseButton = .right
        default: type = down ? .otherMouseDown : .otherMouseUp; mouseButton = .center
        }
        guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: location, mouseButton: mouseButton) else { return }
        event.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
        event.post(tap: .cghidEventTap)
    }
}
