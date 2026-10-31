import Foundation

/// What a physical key sends after remapping. Encoded as a 4-byte slot in the
/// keyboard's 576-byte onboard remap table.
public enum KeyAction: Codable, Hashable, Sendable {
    /// Keep the factory behaviour.
    case none
    /// A keyboard usage (HID page 0x07), optionally with modifiers held.
    case key(usage: UInt8, modifiers: UInt8 = 0)
    /// The key becomes a modifier. Bits: 01 LCtrl, 02 LShift, 04 LAlt, 08 LWin/Cmd.
    case modifier(UInt8)
    /// Media / consumer usage (page 0x0C), encoded as a 16-bit usage.
    case consumer(UInt16)
    /// Vendor special function.
    case special(UInt8, UInt8)
    /// Execute one of the stored macros.
    case macro(index: UInt8, mode: UInt8 = 0, count: UInt8 = 0)
    /// Mouse button / wheel action.
    case mouse(UInt8, UInt8, UInt8)
    /// The key does nothing.
    case disabled

    public var slot: [UInt8] {
        switch self {
        case .none: return [0x00, 0x00, 0x00, 0x00]
        case .key(let usage, let modifiers):
            // A modifier target is encoded as a modifier bit, not a usage.
            if usage >= 0xE0, usage <= 0xE7 {
                let bits: [UInt8] = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80]
                return [0x02, modifiers | bits[Int(usage - 0xE0)], 0x00, 0x00]
            }
            return [0x02, modifiers, usage, 0x00]
        case .modifier(let bits): return [0x02, bits, 0x00, 0x00]
        case .consumer(let usage): return [0x03, UInt8(usage & 0xFF), UInt8((usage >> 8) & 0xFF), 0x00]
        case .special(let a, let b): return [0x01, a, b, 0x00]
        case .macro(let index, let mode, let count): return [0x06, index, mode, count]
        case .mouse(let a, let b, let c): return [0x07, a, b, c]
        case .disabled: return [0x05, 0x03, 0x00, 0x00]
        }
    }

    public var isNoOp: Bool {
        if case .none = self { return true }
        return false
    }

    public var displayName: String {
        switch self {
        case .none: return "Default"
        case .key(let usage, let modifiers):
            let prefix = ModifierBits.symbols(modifiers)
            let keyName = KeyLayout.f108Pro.key(usage: usage)?.label ?? String(format: "0x%02X", usage)
            return prefix + keyName
        case .modifier(let bits):
            return ModifierBits.symbols(bits).isEmpty ? "Modifier" : ModifierBits.symbols(bits)
        case .consumer(let usage):
            return ConsumerControl.name(for: usage) ?? String(format: "Media 0x%02X", usage)
        case .special(let a, let b):
            return Self.specialName(a, b)
        case .macro(let index, _, _):
            return "Macro \(index + 1)"
        case .mouse(let a, let b, let c):
            return Self.mouseName(a, b, c)
        case .disabled:
            return "Disabled"
        }
    }

    public static func specialName(_ a: UInt8, _ b: UInt8) -> String {
        switch (a, b) {
        case (0x01, 0x01): return "Num Lock"
        case (0x01, 0x02): return "Caps Lock"
        case (0x01, 0x03): return "Insert"
        case (0x01, 0x04): return "Scroll Lock"
        case (0x03, 0x01): return "Calculator"
        case (0x03, 0xFF): return "Lock PC"
        case (0x01, 0x08): return "App Switch"
        default: return String(format: "Special %02X %02X", a, b)
        }
    }

    public static func mouseName(_ a: UInt8, _ b: UInt8, _ c: UInt8) -> String {
        if a == 0x00 && b == 0x01 { return "Scroll Up" }
        if a == 0x00 && b == 0xFF { return "Scroll Down" }
        switch a {
        case 0x01: return "Left Click"
        case 0x02: return "Right Click"
        case 0x04: return "Middle Click"
        default: return String(format: "Mouse %02X %02X %02X", a, b, c)
        }
    }

    public static let leftControl = KeyAction.modifier(ModifierBits.leftControl)
    public static let leftShift = KeyAction.modifier(ModifierBits.leftShift)
    public static let leftOption = KeyAction.modifier(ModifierBits.leftOption)
    public static let leftCommand = KeyAction.modifier(ModifierBits.leftCommand)
    public static let rightControl = KeyAction.modifier(ModifierBits.rightControl)
    public static let rightShift = KeyAction.modifier(ModifierBits.rightShift)
    public static let rightOption = KeyAction.modifier(ModifierBits.rightOption)
    public static let rightCommand = KeyAction.modifier(ModifierBits.rightCommand)

    public static let playPause = KeyAction.consumer(0xCD)
    public static let stop = KeyAction.consumer(0xB7)
    public static let previousTrack = KeyAction.consumer(0xB6)
    public static let nextTrack = KeyAction.consumer(0xB5)
    public static let volumeUp = KeyAction.consumer(0xE9)
    public static let volumeDown = KeyAction.consumer(0xEA)
    public static let mute = KeyAction.consumer(0xE2)
}

public enum ConsumerControl {
    public static let names: [(name: String, usage: UInt16, symbol: String)] = [
        ("Play / Pause", 0xCD, "playpause"),
        ("Stop", 0xB7, "stop"),
        ("Previous Track", 0xB6, "backward"),
        ("Next Track", 0xB5, "forward"),
        ("Volume Up", 0xE9, "speaker.plus"),
        ("Volume Down", 0xEA, "speaker.minus"),
        ("Mute", 0xE2, "speaker.slash"),
        ("Calculator", 0x192, "plus.forwardslash.minus"),
        ("Browser Home", 0x223, "safari"),
        ("Search", 0x221, "magnifyingglass"),
    ]

    public static func name(for usage: UInt16) -> String? {
        names.first { $0.usage == usage }?.name
    }
}

public typealias KeyRemapMap = [String: KeyAction]

public enum RemapPresets {
    /// Mac-style modifier positions: Cmd where Alt is, Option where Win is.
    public static let mac: KeyRemapMap = [
        "lalt": .leftCommand,
        "lwin": .leftOption,
        "ralt": .rightCommand,
        "menu": .rightOption,
    ]

    public static let windows: KeyRemapMap = [:]

    /// The stock Windows layout uses Ctrl/Alt/Win, which macOS users often
    /// re-map to Control/Option/Command.
    public static let capsToControl: KeyRemapMap = ["capslock": .leftControl]

    public static let wasdArrows: KeyRemapMap = [
        "w": .key(usage: 0x52),
        "a": .key(usage: 0x50),
        "s": .key(usage: 0x51),
        "d": .key(usage: 0x4F),
    ]

    public static let escapeToGrave: KeyRemapMap = ["esc": .key(usage: 0x35)]
}

/// The 576-byte onboard remap table. One 4-byte slot per key index.
public enum RemapTable {
    public static let size = 0x240

    public static func encode(_ map: KeyRemapMap) -> [UInt8] {
        let layout = KeyLayout.f108Pro
        var table = [UInt8](repeating: 0, count: size)
        for (name, action) in map {
            guard !action.isNoOp, let key = layout.key(named: name) else { continue }
            let offset = Int(key.light) * 4
            guard offset >= 4, offset + 4 <= size - 2 else { continue }
            table.replaceSubrange(offset..<offset + 4, with: action.slot)
        }
        table[size - 2] = 0xAA
        table[size - 1] = 0x55
        return table
    }
}
