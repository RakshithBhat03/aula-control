import SwiftUI
import AppKit
import AulaKit

enum AppSection: String, CaseIterable, Identifiable {
    case overview
    case lighting
    case perKey
    case keymap
    case macros
    case device
    case macRemap
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .lighting: return "Lighting"
        case .perKey: return "Per-key RGB"
        case .keymap: return "Keymap"
        case .macros: return "Macros"
        case .device: return "Device"
        case .macRemap: return "Mac remap"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .lighting: return "light.max"
        case .perKey: return "paintpalette"
        case .keymap: return "keyboard"
        case .macros: return "record.circle"
        case .device: return "slider.horizontal.3"
        case .macRemap: return "command"
        case .settings: return "gearshape"
        }
    }

    var group: String {
        switch self {
        case .overview, .lighting, .perKey, .keymap, .macros, .device: return "Keyboard"
        case .macRemap: return "macOS"
        case .settings: return "App"
        }
    }

    /// Matches the Keyboard menu's ⌘-number shortcuts.
    var shortcut: String {
        switch self {
        case .overview: return "⌘1"
        case .lighting: return "⌘2"
        case .perKey: return "⌘3"
        case .keymap: return "⌘4"
        case .macros: return "⌘5"
        case .macRemap: return "⌘6"
        case .device: return "⌘7"
        case .settings: return "⌘8"
        }
    }
}

enum RemapLayer: String, CaseIterable, Identifiable {
    case normal
    case fn
    var id: String { rawValue }
    var title: String { self == .normal ? "Normal layer" : "FN layer" }
}

struct StatusMessage: Identifiable, Equatable {
    enum Kind { case success, error, info }
    let id = UUID()
    let kind: Kind
    let text: String
}

@MainActor
final class AppModel: ObservableObject {
    @Published var section: AppSection = .overview
    @Published var connection: AulaConnectionInfo = AulaDiscovery.detect()
    @Published var state: AulaState {
        didSet { stateDidChange() }
    }

    @Published var isBusy = false
    @Published var toast: StatusMessage?
    @Published var selectedLayer: RemapLayer = .normal
    @Published var selectedKey: String? = "capslock"
    @Published var focusMacroID: UUID?
    @Published var demoMode = false {
        didSet {
            closeDevice()
            if demoMode {
                connection = AulaConnectionInfo(
                    kind: .wired,
                    product: "AULA F108Pro (preview)",
                    manufacturer: "AULA",
                    transport: "USB · simulated",
                    uniqueID: "SIMULATED-F108PRO",
                    locationID: 0,
                    vendorID: F108.vendorID,
                    productID: F108.productID
                )
                showToast(.info, "Preview mode: changes are simulated, not sent to the keyboard.")
            } else {
                refreshConnection(force: true)
            }
        }
    }

    @Published var accessibilityGranted = AulaPermissions.accessibility
    @Published var inputMonitoringGranted = AulaPermissions.inputMonitoring
    @Published var remapRunning = false
    @Published var remapError: String?
    @Published var lastKeySource: String?
    @Published var karabinerPresent = false
    @Published var launchAtLogin = LaunchAtLogin.isEnabled

    let store: AulaStore
    private let remapper = KeyboardRemapper()
    private var pollTimer: Timer?
    private var saveWork: DispatchWorkItem?
    private var toastWork: DispatchWorkItem?

    private let deviceQueue = DispatchQueue(label: "com.aulacontrol.device")
    private let session = DeviceSession()

    var isPreview: Bool { demoMode || connection.transport.contains("simulated") }
    var canUseHardware: Bool { connection.kind == .wired }
    var connectionColor: Color {
        switch connection.kind {
        case .wired: return demoMode ? Theme.blue : Theme.success
        case .dongle: return Theme.accent
        case .bluetooth: return Theme.blue
        case .absent: return Theme.tertiary
        }
    }

    var hardwareStatusText: String {
        if demoMode { return "Preview mode" }
        switch connection.kind {
        case .wired: return "USB wired"
        case .dongle: return "2.4 GHz"
        case .bluetooth: return "Bluetooth"
        case .absent: return "Not connected"
        }
    }

    init(store: AulaStore = AulaStore()) {
        self.store = store
        self.state = store.load()
        remapper.log = { message in
            #if DEBUG
            print("[remap] \(message)")
            #endif
        }
        remapper.onEventSource = { [weak self] name in
            DispatchQueue.main.async {
                guard let self else { return }
                if self.lastKeySource != name { self.lastKeySource = name }
            }
        }
        refreshConnection(force: true)
        startPolling()
        updateRemapperConfiguration()
        if state.macRemap.enabled {
            startRemapperIfPossible()
        }
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - Connection

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshConnection() }
        }
    }

    func refreshConnection(force: Bool = false) {
        refreshPermissions()
        guard !demoMode else { return }
        let new = AulaDiscovery.detect()
        if force || new.kind != connection.kind || new.product != connection.product || new.uniqueID != connection.uniqueID {
            let wasWired = connection.kind == .wired
            connection = new
            if new.kind != .wired {
                closeDevice()
            }
            if new.kind == .wired && !wasWired {
                if state.autoApplyOnConnect {
                    pushAll()
                } else {
                    showToast(.success, "Keyboard connected over USB. Hardware controls are ready.")
                }
            } else if new.kind == .bluetooth {
                showToast(.info, "Bluetooth connected. macOS remapping is available; hardware settings need USB-C.")
            }
        }
    }

    func refreshPermissions() {
        accessibilityGranted = AulaPermissions.accessibility
        inputMonitoringGranted = AulaPermissions.inputMonitoring
        karabinerPresent = AulaDiscovery.karabinerVirtualKeyboardPresent()
        if state.macRemap.enabled && !remapRunning && accessibilityGranted {
            startRemapperIfPossible()
        }
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    // MARK: - Device operations

    private func closeDevice() {
        let session = self.session
        deviceQueue.async {
            session.close()
        }
    }

    func perform(_ label: String, work: @escaping (AulaDevice, AulaState) throws -> Void) {
        guard !isBusy else { return }
        if !isPreview && connection.kind != .wired {
            showToast(.error, "Hardware settings need USB-C. Connect the cable and press Fn + 4.")
            return
        }
        isBusy = true
        let snapshot = state
        let preview = isPreview
        let session = self.session
        deviceQueue.async { [weak self] in
            guard let self else { return }
            do {
                let device = try session.device(preview: preview)
                try work(device, snapshot)
                DispatchQueue.main.async {
                    self.isBusy = false
                    self.showToast(.success, preview ? "\(label) (simulated)." : "\(label) sent to the keyboard.")
                }
            } catch {
                DispatchQueue.main.async {
                    self.isBusy = false
                    session.close()
                    self.showToast(.error, error.localizedDescription)
                }
            }
        }
    }

    func applyLighting() {
        perform("Lighting") { device, state in
            try device.setLighting(state.lighting)
        }
    }

    func applyPerKey() {
        perform("Per-key colors") { device, state in
            try device.setPerKey(state.perKeyColors(), brightness: state.perKeyBrightness)
        }
    }

    func applyKeymap() {
        let layer = selectedLayer
        perform("Keymap") { device, state in
            if !state.macros.isEmpty {
                try device.setMacros(state.macros)
            }
            try device.setRemap(layer == .normal ? state.keymap : state.fnKeymap, fnLayer: layer == .fn)
        }
    }

    func uploadMacros() {
        perform("Macros") { device, state in
            try device.setMacros(state.macros)
        }
    }

    func applyOptions() {
        perform("Device options") { device, state in
            try device.setOptions(state.options)
        }
    }

    func syncClock() {
        perform("Clock") { device, _ in
            try device.syncClock()
        }
    }

    func pushAll() {
        perform("Configuration") { device, state in
            try device.pushAll(state)
        }
    }

    func resetOnboardKeymap() {
        let layer = selectedLayer
        perform("Reset keymap") { device, _ in
            try device.resetRemap(fnLayer: layer == .fn)
        }
        if layer == .normal { state.keymap = [:] } else { state.fnKeymap = [:] }
    }

    // MARK: - Editing helpers

    func setLightingMode(_ mode: LightingMode) {
        state.lighting.mode = mode
        if mode.forcesRainbow { state.lighting.colorful = true }
    }

    func setPerKey(_ key: KeyCap, color: AulaRGB) {
        state.perKey[key.name] = color
    }

    func clearPerKey(_ key: KeyCap) {
        state.perKey.removeValue(forKey: key.name)
    }

    func fillPerKey(_ color: AulaRGB) {
        for key in KeyLayout.f108Pro.keys { state.perKey[key.name] = color }
    }

    func clearAllPerKey() {
        state.perKey.removeAll()
    }

    func applyPerKeyPreset(_ preset: PerKeyPreset) {
        state.perKey = preset.colors()
    }

    func setKeymap(_ name: String, action: KeyAction?, layer: RemapLayer) {
        if layer == .normal {
            if let action, !action.isNoOp { state.keymap[name] = action } else { state.keymap.removeValue(forKey: name) }
        } else {
            if let action, !action.isNoOp { state.fnKeymap[name] = action } else { state.fnKeymap.removeValue(forKey: name) }
        }
    }

    func setMacRemap(_ name: String, action: KeyAction?) {
        if let action, !action.isNoOp { state.macRemap.map[name] = action }
        else { state.macRemap.map.removeValue(forKey: name) }
    }

    func addMacro() {
        let macro = Macro(name: "Macro \(state.macros.count + 1)")
        state.macros.append(macro)
        focusMacroID = macro.id
    }

    func updateMacro(_ macro: Macro) {
        guard let index = state.macros.firstIndex(where: { $0.id == macro.id }) else { return }
        state.macros[index] = macro
    }

    func deleteMacro(_ macro: Macro) {
        state.macros.removeAll { $0.id == macro.id }
    }

    func duplicateMacro(_ macro: Macro) {
        var copy = macro
        copy.id = UUID()
        copy.name += " copy"
        state.macros.append(copy)
    }

    // MARK: - macOS remapping

    func updateRemapperConfiguration() {
        remapper.update(
            rules: state.macRemap.map,
            macros: state.macros,
            onlyThisKeyboard: state.macRemap.onlyThisKeyboard
        )
    }

    func setMacRemapEnabled(_ enabled: Bool) {
        state.macRemap.enabled = enabled
        stateDidChange()
        if enabled {
            startRemapperIfPossible()
        } else {
            remapper.stop()
            remapRunning = false
            remapError = nil
            showToast(.info, "macOS remapping stopped.")
        }
    }

    func startRemapperIfPossible() {
        guard state.macRemap.enabled else { return }
        guard accessibilityGranted else {
            remapError = "Accessibility permission is required."
            showToast(.info, "Grant Accessibility to enable macOS remapping.")
            return
        }
        do {
            updateRemapperConfiguration()
            _ = try remapper.start()
            remapRunning = true
            remapError = nil
        } catch {
            remapRunning = false
            remapError = error.localizedDescription
            showToast(.error, error.localizedDescription)
        }
    }

    func requestAccessibility() {
        let granted = AulaPermissions.requestAccessibility()
        accessibilityGranted = granted
        AulaPermissions.openAccessibilitySettings()
        showToast(.info, "Enable AULA Control under Privacy & Security → Accessibility, then return here.")
    }

    func requestInputMonitoring() {
        _ = AulaPermissions.requestInputMonitoring()
        inputMonitoringGranted = AulaPermissions.inputMonitoring
        AulaPermissions.openInputMonitoringSettings()
        showToast(.info, "Enable AULA Control under Privacy & Security → Input Monitoring, then relaunch.")
    }

    func applyMacPreset() {
        state.macRemap.map = RemapPresets.mac
        stateDidChange()
    }

    func clearMacRemap() {
        state.macRemap.map = [:]
        stateDidChange()
    }

    // MARK: - Settings

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.set(enabled)
            launchAtLogin = LaunchAtLogin.isEnabled
            if LaunchAtLogin.requiresApproval {
                LaunchAtLogin.openSettings()
                showToast(.info, "Allow AULA Control in System Settings → General → Login Items.")
            }
        } catch {
            launchAtLogin = LaunchAtLogin.isEnabled
            showToast(.error, "Could not update login item: \(error.localizedDescription)")
        }
    }

    func revealStateFile() {
        NSWorkspace.shared.activateFileViewerSelecting([store.url])
    }

    // MARK: - Persistence

    private func stateDidChange() {
        scheduleSave()
        updateRemapperConfiguration()
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let snapshot = state
        let work = DispatchWorkItem { [store] in
            try? store.save(snapshot)
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    func showToast(_ kind: StatusMessage.Kind, _ text: String) {
        toast = StatusMessage(kind: kind, text: text)
        toastWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.easeOut(duration: 0.2)) { self?.toast = nil }
        }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2, execute: work)
    }
}

final class DeviceSession: @unchecked Sendable {
    private var device: AulaDevice?
    private var previewTransport: RecordingTransport?
    private var isPreview = false

    func device(preview: Bool) throws -> AulaDevice {
        if let device, isPreview == preview { return device }
        close()
        isPreview = preview
        if preview {
            let transport = RecordingTransport()
            let new = AulaDevice(transport: transport, commandDelay: 0)
            previewTransport = transport
            device = new
            return new
        }
        let new = try AulaDiscovery.openWired()
        device = new
        return new
    }

    func close() {
        device?.close()
        device = nil
        previewTransport = nil
    }
}

struct PerKeyPreset: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    let colors: () -> [String: AulaRGB]

    static let all: [PerKeyPreset] = [
        PerKeyPreset(name: "Sunset", symbol: "sunset.fill") {
            var map: [String: AulaRGB] = [:]
            for (index, key) in KeyLayout.f108Pro.keys.enumerated() {
                let hue = 0.02 + Double(index % 16) / 16 * 0.10
                map[key.name] = AulaRGB.hue(hue)
            }
            return map
        },
        PerKeyPreset(name: "Ocean", symbol: "water.waves") {
            var map: [String: AulaRGB] = [:]
            for (index, key) in KeyLayout.f108Pro.keys.enumerated() {
                let hue = 0.48 + Double(index % 18) / 18 * 0.13
                map[key.name] = AulaRGB.hue(hue)
            }
            return map
        },
        PerKeyPreset(name: "WASD", symbol: "gamecontroller.fill") {
            var map: [String: AulaRGB] = [:]
            for key in KeyLayout.f108Pro.keys {
                map[key.name] = AulaRGB(12, 14, 18)
            }
            for name in ["w", "a", "s", "d", "esc", "space"] {
                map[name] = AulaRGB(255, 176, 32)
            }
            return map
        },
        PerKeyPreset(name: "Mint fade", symbol: "leaf.fill") {
            var map: [String: AulaRGB] = [:]
            for key in KeyLayout.f108Pro.keys {
                let t = min(1, max(0, (key.y + 1) / 7))
                map[key.name] = AulaRGB(
                    UInt8(70 + 20 * t),
                    UInt8(210 - 100 * t),
                    UInt8(180 - 60 * t)
                )
            }
            return map
        },
    ]
}
