import Foundation
import CoreGraphics

/// One physical key on the F108 Pro. Coordinates are in key units (1u = one
/// letter key) and match the physical full-size ANSI layout.
public struct KeyCap: Identifiable, Hashable, Sendable {
    public let light: UInt8
    public let name: String
    public let label: String
    public let sublabel: String?
    /// USB HID keyboard usage (page 0x07). The Fn key uses the vendor code 0xAF.
    public let usage: UInt8
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public let isNumpad: Bool

    public var id: String { name }

    public var macKeyCode: CGKeyCode? {
        KeyLayout.macKeyCode(forUsage: usage)
    }

    public var isModifier: Bool {
        (0xE0...0xE7).contains(usage) || usage == 0xAF
    }
}

public struct KeyLayout: Sendable {
    public let keys: [KeyCap]
    public let widthUnits: Double
    public let heightUnits: Double

    public func key(named name: String) -> KeyCap? {
        let n = name.lowercased()
        return keys.first { $0.name.lowercased() == n }
    }

    public func key(light: UInt8) -> KeyCap? {
        keys.first { $0.light == light }
    }

    public func key(usage: UInt8) -> KeyCap? {
        keys.first { $0.usage == usage }
    }

    /// The full-size ANSI layout of the F108 Pro. Light indices are the vendor's
    /// `key_index` / `light_index` values (1...123, with gaps).
    public static let f108Pro: KeyLayout = {
        var keys: [KeyCap] = []

        func add(
            _ light: UInt8, _ name: String, _ label: String, _ usage: UInt8,
            x: Double, y: Double, w: Double = 1, h: Double = 1, sub: String? = nil,
            numpad: Bool = false
        ) {
            keys.append(KeyCap(
                light: light, name: name, label: label, sublabel: sub, usage: usage,
                x: x, y: y, width: w, height: h, isNumpad: numpad
            ))
        }

        // Row 0 — function row.
        add(1, "esc", "Esc", 0x29, x: 0, y: 0)
        let functionKeys: [(UInt8, String, String)] = [
            (2, "f1", "F1"), (3, "f2", "F2"), (4, "f3", "F3"), (5, "f4", "F4"),
            (6, "f5", "F5"), (7, "f6", "F6"), (8, "f7", "F7"), (9, "f8", "F8"),
            (10, "f9", "F9"), (11, "f10", "F10"), (12, "f11", "F11"), (13, "f12", "F12"),
        ]
        for (i, f) in functionKeys.enumerated() {
            let groupGap = i < 4 ? 1.0 : (i < 8 ? 0.5 : 0.5)
            let base = i < 4 ? 2.0 : (i < 8 ? 6.5 : 10.5)
            add(f.0, f.1, f.2, UInt8(0x3A + i), x: base + Double(i % 4) + (i >= 4 && i < 8 ? 0 : 0), y: 0)
            _ = groupGap
        }
        add(112, "printscreen", "PrtSc", 0x46, x: 15.25, y: 0)
        add(113, "scrolllock", "ScrLk", 0x47, x: 16.25, y: 0)
        add(115, "pause", "Pause", 0x48, x: 17.25, y: 0)

        // Row 1 — numbers + navigation + numpad top.
        add(19, "grave", "`", 0x35, x: 0, y: 1.25, sub: "~")
        let numberKeys: [(UInt8, String, String, UInt8, String)] = [
            (20, "1", "1", 0x1E, "!"), (21, "2", "2", 0x1F, "@"),
            (22, "3", "3", 0x20, "#"), (23, "4", "4", 0x21, "$"),
            (24, "5", "5", 0x22, "%"), (25, "6", "6", 0x23, "^"),
            (26, "7", "7", 0x24, "&"), (27, "8", "8", 0x25, "*"),
            (28, "9", "9", 0x26, "("), (29, "0", "0", 0x27, ")"),
            (30, "minus", "-", 0x2D, "_"), (31, "equal", "=", 0x2E, "+"),
        ]
        for (i, k) in numberKeys.enumerated() {
            add(k.0, k.1, k.2, k.3, x: 1 + Double(i), y: 1.25, sub: k.4)
        }
        add(103, "backspace", "⌫", 0x2A, x: 13, y: 1.25, w: 2)
        add(116, "insert", "Ins", 0x49, x: 15.25, y: 1.25)
        add(117, "home", "Home", 0x4A, x: 16.25, y: 1.25)
        add(118, "pageup", "PgUp", 0x4B, x: 17.25, y: 1.25)
        add(32, "numlock", "Num", 0x53, x: 18.5, y: 1.25, sub: "Lock", numpad: true)
        add(33, "numslash", "/", 0x54, x: 19.5, y: 1.25, numpad: true)
        add(34, "numstar", "*", 0x55, x: 20.5, y: 1.25, numpad: true)
        add(122, "numminus", "−", 0x56, x: 21.5, y: 1.25, numpad: true)

        // Row 2 — QWERTY + navigation + numpad.
        add(37, "tab", "Tab", 0x2B, x: 0, y: 2.25, w: 1.5, sub: "⇥")
        let letters = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
        let letterUsages: [UInt8] = [0x14, 0x1A, 0x08, 0x15, 0x17, 0x1C, 0x18, 0x0C, 0x12, 0x13]
        let letterLights: [UInt8] = [38, 39, 40, 41, 42, 43, 44, 45, 46, 47]
        for i in 0..<letters.count {
            add(letterLights[i], letters[i], letters[i].uppercased(), letterUsages[i], x: 1.5 + Double(i), y: 2.25)
        }
        add(48, "lbracket", "[", 0x2F, x: 11.5, y: 2.25, sub: "{")
        add(49, "rbracket", "]", 0x30, x: 12.5, y: 2.25, sub: "}")
        add(67, "backslash", "\\", 0x31, x: 13.5, y: 2.25, w: 1.5, sub: "|")
        add(119, "delete", "Del", 0x4C, x: 15.25, y: 2.25)
        add(120, "end", "End", 0x4D, x: 16.25, y: 2.25)
        add(121, "pagedown", "PgDn", 0x4E, x: 17.25, y: 2.25)
        add(50, "num7", "7", 0x5F, x: 18.5, y: 2.25, sub: "Home", numpad: true)
        add(51, "num8", "8", 0x60, x: 19.5, y: 2.25, sub: "↑", numpad: true)
        add(52, "num9", "9", 0x61, x: 20.5, y: 2.25, sub: "PgUp", numpad: true)
        add(123, "numplus", "+", 0x57, x: 21.5, y: 2.25, h: 2, numpad: true)

        // Row 3 — home row + numpad.
        add(55, "capslock", "Caps", 0x39, x: 0, y: 3.25, w: 1.75, sub: "Lock")
        let homeLetters = ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
        let homeUsages: [UInt8] = [0x04, 0x16, 0x07, 0x09, 0x0A, 0x0B, 0x0D, 0x0E, 0x0F]
        let homeLights: [UInt8] = [56, 57, 58, 59, 60, 61, 62, 63, 64]
        for i in 0..<homeLetters.count {
            add(homeLights[i], homeLetters[i], homeLetters[i].uppercased(), homeUsages[i], x: 1.75 + Double(i), y: 3.25)
        }
        add(65, "semicolon", ";", 0x33, x: 10.75, y: 3.25, sub: ":")
        add(66, "quote", "'", 0x34, x: 11.75, y: 3.25, sub: "\"")
        add(85, "enter", "⏎", 0x28, x: 12.75, y: 3.25, w: 2.25, sub: "Enter")
        add(68, "num4", "4", 0x5C, x: 18.5, y: 3.25, sub: "←", numpad: true)
        add(69, "num5", "5", 0x5D, x: 19.5, y: 3.25, numpad: true)
        add(70, "num6", "6", 0x5E, x: 20.5, y: 3.25, sub: "→", numpad: true)

        // Row 4 — shift row + arrows + numpad.
        add(73, "lshift", "⇧", 0xE1, x: 0, y: 4.25, w: 2.25, sub: "Shift")
        let shiftLetters = ["z", "x", "c", "v", "b", "n", "m"]
        let shiftUsages: [UInt8] = [0x1D, 0x1B, 0x06, 0x19, 0x05, 0x11, 0x10]
        let shiftLights: [UInt8] = [74, 75, 76, 77, 78, 79, 80]
        for i in 0..<shiftLetters.count {
            add(shiftLights[i], shiftLetters[i], shiftLetters[i].uppercased(), shiftUsages[i], x: 2.25 + Double(i), y: 4.25)
        }
        add(81, "comma", ",", 0x36, x: 9.25, y: 4.25, sub: "<")
        add(82, "dot", ".", 0x37, x: 10.25, y: 4.25, sub: ">")
        add(83, "slash", "/", 0x38, x: 11.25, y: 4.25, sub: "?")
        add(84, "rshift", "⇧", 0xE5, x: 12.25, y: 4.25, w: 2.75, sub: "Shift")
        add(101, "up", "↑", 0x52, x: 16.25, y: 4.25)
        add(86, "num1", "1", 0x59, x: 18.5, y: 4.25, sub: "End", numpad: true)
        add(87, "num2", "2", 0x5A, x: 19.5, y: 4.25, sub: "↓", numpad: true)
        add(88, "num3", "3", 0x5B, x: 20.5, y: 4.25, sub: "PgDn", numpad: true)
        add(106, "numenter", "⏎", 0x58, x: 21.5, y: 4.25, h: 2, numpad: true)

        // Row 5 — bottom row + arrows + numpad.
        add(91, "lctrl", "⌃", 0xE0, x: 0, y: 5.25, w: 1.25, sub: "Ctrl")
        add(92, "lwin", "⌘", 0xE3, x: 1.25, y: 5.25, w: 1.25, sub: "Win")
        add(93, "lalt", "⌥", 0xE2, x: 2.5, y: 5.25, w: 1.25, sub: "Alt")
        add(94, "space", "", 0x2C, x: 3.75, y: 5.25, w: 6.25)
        add(95, "ralt", "⌥", 0xE6, x: 10, y: 5.25, w: 1.25, sub: "Alt")
        add(96, "fn", "Fn", 0xAF, x: 11.25, y: 5.25, w: 1.25)
        add(97, "menu", "☰", 0x65, x: 12.5, y: 5.25, w: 1.25, sub: "Menu")
        add(98, "rctrl", "⌃", 0xE4, x: 13.75, y: 5.25, w: 1.25, sub: "Ctrl")
        add(99, "left", "←", 0x50, x: 15.25, y: 5.25)
        add(100, "down", "↓", 0x51, x: 16.25, y: 5.25)
        add(102, "right", "→", 0x4F, x: 17.25, y: 5.25)
        add(104, "num0", "0", 0x62, x: 18.5, y: 5.25, w: 2, sub: "Ins", numpad: true)
        add(105, "numdot", ".", 0x63, x: 20.5, y: 5.25, sub: "Del", numpad: true)

        return KeyLayout(keys: keys, widthUnits: 22.5, heightUnits: 6.25)
    }()

    /// USB HID keyboard usage → macOS virtual keycode (ANSI layout).
    public static let macKeyCodeByUsage: [UInt8: CGKeyCode] = [
        0x04: 0, 0x05: 11, 0x06: 8, 0x07: 2, 0x08: 14, 0x09: 3, 0x0A: 5, 0x0B: 4,
        0x0C: 34, 0x0D: 38, 0x0E: 40, 0x0F: 37, 0x10: 46, 0x11: 45, 0x12: 31,
        0x13: 35, 0x14: 12, 0x15: 15, 0x16: 1, 0x17: 17, 0x18: 32, 0x19: 9,
        0x1A: 13, 0x1B: 7, 0x1C: 16, 0x1D: 6,
        0x1E: 18, 0x1F: 19, 0x20: 20, 0x21: 21, 0x22: 23, 0x23: 22, 0x24: 26,
        0x25: 28, 0x26: 25, 0x27: 29, 0x28: 36, 0x29: 53, 0x2A: 51, 0x2B: 48,
        0x2C: 49, 0x2D: 27, 0x2E: 24, 0x2F: 33, 0x30: 30, 0x31: 42, 0x32: 42,
        0x33: 41, 0x34: 39, 0x35: 50, 0x36: 43, 0x37: 47, 0x38: 44, 0x39: 57,
        0x3A: 122, 0x3B: 120, 0x3C: 99, 0x3D: 118, 0x3E: 96, 0x3F: 97,
        0x40: 98, 0x41: 100, 0x42: 101, 0x43: 109, 0x44: 103, 0x45: 111,
        0x46: 105, 0x47: 107, 0x48: 113, 0x49: 114, 0x4A: 115, 0x4B: 116,
        0x4C: 117, 0x4D: 119, 0x4E: 121, 0x4F: 124, 0x50: 123, 0x51: 125,
        0x52: 126, 0x53: 71, 0x54: 75, 0x55: 67, 0x56: 78, 0x57: 69,
        0x58: 76, 0x59: 83, 0x5A: 84, 0x5B: 85, 0x5C: 86, 0x5D: 87,
        0x5E: 88, 0x5F: 89, 0x60: 91, 0x61: 92, 0x62: 82, 0x63: 65,
        0x64: 10, 0x65: 110, 0x66: 117, 0x67: 81,
        0x68: 105, 0x69: 107, 0x6A: 113, 0x6B: 106, 0x6C: 64, 0x6D: 79,
        0x6E: 80, 0x6F: 90, 0x70: 106,
        0xE0: 59, 0xE1: 56, 0xE2: 58, 0xE3: 55, 0xE4: 62, 0xE5: 60,
        0xE6: 61, 0xE7: 54,
    ]

    /// macOS virtual keycode → HID usage. Excludes duplicate aliases where the
    /// F-key aliases (F13...F15) collide with Print/Scroll/Pause.
    public static let usageByMacKeyCode: [CGKeyCode: UInt8] = {
        var map: [CGKeyCode: UInt8] = [:]
        for (usage, code) in macKeyCodeByUsage {
            if map[code] == nil { map[code] = usage }
        }
        // Prefer the primary keys for aliased codes.
        map[105] = 0x46  // Print Screen aliases F13's keycode
        map[107] = 0x47  // Scroll Lock aliases F14
        map[113] = 0x48  // Pause aliases F15
        map[42] = 0x31   // ANSI backslash, not the non-US # alias
        map[114] = 0x49
        map[117] = 0x4C
        map[110] = 0x65
        map[76] = 0x58
        return map
    }()

    public static func macKeyCode(forUsage usage: UInt8) -> CGKeyCode? {
        macKeyCodeByUsage[usage]
    }

    public static func usage(forMacKeyCode code: CGKeyCode) -> UInt8? {
        usageByMacKeyCode[code]
    }

    public static func hidName(forUsage usage: UInt8) -> String {
        f108Pro.key(usage: usage)?.name ?? String(format: "0x%02X", usage)
    }
}

/// Modifier bit helpers. The same bit layout is used by the keyboard's remap
/// protocol and by the macOS remapper.
public enum ModifierBits {
    public static let leftControl: UInt8 = 0x01
    public static let leftShift: UInt8 = 0x02
    public static let leftOption: UInt8 = 0x04
    public static let leftCommand: UInt8 = 0x08
    public static let rightControl: UInt8 = 0x10
    public static let rightShift: UInt8 = 0x20
    public static let rightOption: UInt8 = 0x40
    public static let rightCommand: UInt8 = 0x80

    public static let all: [(name: String, short: String, bit: UInt8)] = [
        ("Control", "⌃", leftControl),
        ("Shift", "⇧", leftShift),
        ("Option", "⌥", leftOption),
        ("Command", "⌘", leftCommand),
        ("Right Control", "⌃", rightControl),
        ("Right Shift", "⇧", rightShift),
        ("Right Option", "⌥", rightOption),
        ("Right Command", "⌘", rightCommand),
    ]

    public static func symbols(_ bits: UInt8) -> String {
        var s = ""
        if bits & leftControl != 0 || bits & rightControl != 0 { s += "⌃" }
        if bits & leftShift != 0 || bits & rightShift != 0 { s += "⇧" }
        if bits & leftOption != 0 || bits & rightOption != 0 { s += "⌥" }
        if bits & leftCommand != 0 || bits & rightCommand != 0 { s += "⌘" }
        return s
    }
}
