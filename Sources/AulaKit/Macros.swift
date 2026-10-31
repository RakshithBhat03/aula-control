import Foundation

public enum MacroStep: Codable, Hashable, Sendable {
    case key(usage: UInt8, down: Bool)
    case mouse(button: UInt8, down: Bool)
    case delay(milliseconds: UInt16)

    public var displayName: String {
        switch self {
        case .key(let usage, let down):
            let name = KeyLayout.f108Pro.key(usage: usage)?.label ?? String(format: "0x%02X", usage)
            return "\(name) \(down ? "down" : "up")"
        case .mouse(let button, let down):
            return "Mouse \(button) \(down ? "down" : "up")"
        case .delay(let ms):
            return "Wait \(ms) ms"
        }
    }
}

public enum MacroPlayMode: Int, Codable, CaseIterable, Sendable {
    case once = 0
    case repeatCount = 1
    case toggle = 2
    case hold = 3

    public var name: String {
        switch self {
        case .once: return "Play once"
        case .repeatCount: return "Repeat"
        case .toggle: return "Toggle"
        case .hold: return "While held"
        }
    }
}

public struct Macro: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var steps: [MacroStep]
    public var playMode: MacroPlayMode
    public var repeatCount: Int

    public init(
        id: UUID = UUID(),
        name: String,
        steps: [MacroStep] = [],
        playMode: MacroPlayMode = .once,
        repeatCount: Int = 1
    ) {
        self.id = id
        self.name = name
        self.steps = steps
        self.playMode = playMode
        self.repeatCount = max(1, min(repeatCount, 99))
    }

    /// A readable summary, e.g. `⌘C, wait 40 ms, ⌘V`.
    public var summary: String {
        steps.compactMap { step -> String? in
            switch step {
            case .key(let usage, let down):
                guard down else { return nil }
                return KeyLayout.f108Pro.key(usage: usage)?.label ?? String(format: "0x%02X", usage)
            case .mouse(_, let down):
                return down ? "Click" : nil
            case .delay(let ms):
                return "\(ms) ms"
            }
        }.joined(separator: " · ")
    }

    public mutating func appendKey(_ usage: UInt8, gap: UInt16 = 12) {
        if let last = steps.last, case .delay = last {
            // Already separated by a pause.
        } else {
            steps.append(.delay(milliseconds: gap))
        }
        steps.append(.key(usage: usage, down: true))
        steps.append(.key(usage: usage, down: false))
        steps.append(.delay(milliseconds: gap))
    }

    /// Appends a mouse click (button 1 = left, 2 = right, 3 = middle).
    public mutating func appendMouseClick(button: UInt8, gap: UInt16 = 20) {
        steps.append(.mouse(button: button, down: true))
        steps.append(.delay(milliseconds: 10))
        steps.append(.mouse(button: button, down: false))
        steps.append(.delay(milliseconds: gap))
    }
}

/// Serialises the macro bank into the keyboard's fixed 0xE00-byte region.
public enum MacroTable {    public static let headerSize = 400
    public static let maxSize = 0xE00

    public static func encode(_ macros: [Macro]) -> [UInt8] {
        let macros = Array(macros.prefix(100))
        var data = [UInt8](repeating: 0, count: headerSize)
        var cursor = headerSize

        for (index, macro) in macros.enumerated() {
            let offset = cursor
            var block: [UInt8] = [0, 0]
            let events = encodedEvents(macro.steps)
            let count = UInt16(min(events.count, Int(UInt16.max)))
            block[0] = UInt8(count & 0xFF)
            block[1] = UInt8((count >> 8) & 0xFF)
            block.append(contentsOf: [UInt8](repeating: 0, count: 6))
            block.append(contentsOf: events)
            data.append(contentsOf: block)
            cursor += block.count

            let slot = index * 4
            data[slot] = UInt8(offset & 0xFF)
            data[slot + 1] = UInt8((offset >> 8) & 0xFF)
            data[slot + 2] = 0x00
            data[slot + 3] = 0x00
        }

        // Empty macro slots.
        for index in macros.count..<100 {
            let slot = index * 4
            data[slot] = 0xFF; data[slot + 1] = 0xFF
            data[slot + 2] = 0xFF; data[slot + 3] = 0xFF
        }

        // Pad to a whole number of 64-byte reports, always leaving room for the
        // trailer. The firmware expects at least one report.
        var padded = (data.count + F108.reportSize - 1) / F108.reportSize * F108.reportSize
        if padded == data.count { padded += F108.reportSize }
        if padded > maxSize { padded = maxSize }
        if padded < F108.reportSize { padded = F108.reportSize }
        if data.count > maxSize - 2 {
            data = Array(data.prefix(maxSize - 2))
        }
        data.append(contentsOf: [UInt8](repeating: 0, count: max(0, padded - data.count)))
        data[data.count - 2] = 0xAA
        data[data.count - 1] = 0x55
        return data
    }

    public static func encodedEvents(_ steps: [MacroStep]) -> [UInt8] {
        var out: [UInt8] = []
        for step in steps {
            switch step {
            case .key(let usage, let down):
                out.append(contentsOf: [0x00, 0x00, usage, down ? 0xB0 : 0x30])
            case .mouse(let button, let down):
                let wire: UInt8
                switch button {
                case 1: wire = 0x01
                case 2: wire = 0x04
                case 3: wire = 0x02
                default: wire = button
                }
                out.append(contentsOf: [0x00, 0x00, wire, down ? 0x90 : 0x10])
            case .delay(let milliseconds):
                let ms = max(10, milliseconds)
                out.append(contentsOf: [UInt8(ms & 0xFF), UInt8((ms >> 8) & 0xFF), 0x00, 0x50])
            }
        }
        return out
    }

    public static func reportCount(for buffer: [UInt8]) -> UInt8 {
        UInt8(min(255, (buffer.count + F108.reportSize - 1) / F108.reportSize))
    }
}

public extension Macro {
    /// Builds a macro that types a string on a US ANSI layout. Shifted
    /// characters are emitted as Shift down / key / Shift up steps.
    static func typing(_ text: String, name: String? = nil) -> Macro {
        var steps: [MacroStep] = []
        for character in text {
            guard let key = Self.keyForCharacter(character) else { continue }
            if key.shift {
                steps.append(.key(usage: 0xE1, down: true))
            }
            steps.append(.key(usage: key.usage, down: true))
            steps.append(.key(usage: key.usage, down: false))
            if key.shift {
                steps.append(.key(usage: 0xE1, down: false))
            }
            steps.append(.delay(milliseconds: 18))
        }
        return Macro(name: name ?? "Type “\(text.prefix(24))”", steps: steps)
    }

    private static func keyForCharacter(_ character: Character) -> (usage: UInt8, shift: Bool)? {
        let lower = Character(character.lowercased())
        if let scalar = lower.unicodeScalars.first, scalar.value >= 97, scalar.value <= 122 {
            let usage = UInt8(0x04 + (scalar.value - 97))
            return (usage, character.isUppercase)
        }
        let digits: [Character: UInt8] = [
            "1": 0x1E, "2": 0x1F, "3": 0x20, "4": 0x21, "5": 0x22,
            "6": 0x23, "7": 0x24, "8": 0x25, "9": 0x26, "0": 0x27,
        ]
        if let usage = digits[character] { return (usage, false) }

        switch character {
        case " ": return (0x2C, false)
        case "\n", "\r": return (0x28, false)
        case "\t": return (0x2B, false)
        case "-": return (0x2D, false)
        case "_": return (0x2D, true)
        case "=": return (0x2E, false)
        case "+": return (0x2E, true)
        case "[": return (0x2F, false)
        case "{": return (0x2F, true)
        case "]": return (0x30, false)
        case "}": return (0x30, true)
        case "\\": return (0x31, false)
        case "|": return (0x31, true)
        case ";": return (0x33, false)
        case ":": return (0x33, true)
        case "'": return (0x34, false)
        case "\"": return (0x34, true)
        case "`": return (0x35, false)
        case "~": return (0x35, true)
        case ",": return (0x36, false)
        case "<": return (0x36, true)
        case ".": return (0x37, false)
        case ">": return (0x37, true)
        case "/": return (0x38, false)
        case "?": return (0x38, true)
        case "!": return (0x1E, true)
        case "@": return (0x1F, true)
        case "#": return (0x20, true)
        case "$": return (0x21, true)
        case "%": return (0x22, true)
        case "^": return (0x23, true)
        case "&": return (0x24, true)
        case "*": return (0x25, true)
        case "(": return (0x26, true)
        case ")": return (0x27, true)
        default: return nil
        }
    }
}
