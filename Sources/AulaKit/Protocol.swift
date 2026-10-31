import Foundation

/// Wire-level constants for the AULA F108 Pro configuration protocol.
///
/// The protocol was recovered from AULA's Windows driver and has been verified
/// on hardware by several independent projects (see README acknowledgements).
public enum F108 {
    public static let vendorID = 0x0C45          // Sonix / Microdia
    public static let productID = 0x800A
    public static let wirelessVendorID = 0x05AC  // the dongle spoofs Apple's IDs
    public static let wirelessProductID = 0x024F

    /// Interface 3: 64-byte feature reports (all configuration commands).
    public static let configUsagePage = 0xFF13
    /// Interface 2: 4096-byte output reports (LCD pixels).
    public static let lcdUsagePage = 0xFF68

    public static let reportSize = 64
    public static let commandDelay: TimeInterval = 0.035
    public static let firmwareDelay: TimeInterval = 0.030

    public static let productPrefix = "AULA-F108Pro"
    public static let displayName = "AULA F108 Pro"
}

public enum AulaError: LocalizedError, Equatable {
    case notFound
    case bluetoothOnly
    case missingInterface(String)
    case io(String, Int32)
    case malformed(String)
    case transportClosed

    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "AULA F108 Pro not found. Plug in the USB-C cable and select USB mode (Fn + 4)."
        case .bluetoothOnly:
            return "The keyboard is connected over Bluetooth. Lighting, per-key RGB, onboard remapping and macros need the wired USB connection (Fn + 4)."
        case .missingInterface(let name):
            return "The keyboard is present but its \(name) interface is unavailable."
        case .io(let what, let code):
            return String(format: "%@ failed (IOReturn 0x%08X). Check Input Monitoring permission.", what, UInt32(bitPattern: code))
        case .malformed(let why):
            return "Invalid protocol data: \(why)"
        case .transportClosed:
            return "The keyboard is no longer connected."
        }
    }
}

/// The 20 firmware lighting effects exposed by the F108 Pro.
public enum LightingMode: Int, CaseIterable, Codable, Identifiable, Sendable {
    case off = 0
    case staticColor = 1
    case singleOn = 2
    case singleOff = 3
    case glittering = 4
    case falling = 5
    case colourful = 6
    case breath = 7
    case spectrum = 8
    case outward = 9
    case scrolling = 10
    case rolling = 11
    case rotating = 12
    case explode = 13
    case launch = 14
    case ripples = 15
    case flowing = 16
    case pulsating = 17
    case tilt = 18
    case shuttle = 19

    public var id: Int { rawValue }

    public var name: String {
        switch self {
        case .off: return "Off"
        case .staticColor: return "Static"
        case .singleOn: return "Single On"
        case .singleOff: return "Single Off"
        case .glittering: return "Glittering"
        case .falling: return "Falling"
        case .colourful: return "Colourful"
        case .breath: return "Breath"
        case .spectrum: return "Spectrum"
        case .outward: return "Outward"
        case .scrolling: return "Scrolling"
        case .rolling: return "Rolling"
        case .rotating: return "Rotating"
        case .explode: return "Explode"
        case .launch: return "Launch"
        case .ripples: return "Ripples"
        case .flowing: return "Flowing"
        case .pulsating: return "Pulsating"
        case .tilt: return "Tilt"
        case .shuttle: return "Shuttle"
        }
    }

    public var symbol: String {
        switch self {
        case .off: return "power"
        case .staticColor: return "paintpalette"
        case .singleOn: return "lightbulb"
        case .singleOff: return "lightbulb.slash"
        case .glittering: return "sparkles"
        case .falling: return "arrow.down"
        case .colourful: return "rainbow"
        case .breath: return "wind"
        case .spectrum: return "circle.grid.cross"
        case .outward: return "arrow.up.left.and.arrow.down.right"
        case .scrolling: return "arrow.right.to.line"
        case .rolling: return "water.waves"
        case .rotating: return "arrow.triangle.2.circlepath"
        case .explode: return "burst"
        case .launch: return "paperplane"
        case .ripples: return "dot.radiowaves.left.and.right"
        case .flowing: return "arrow.left.arrow.right"
        case .pulsating: return "waveform.path.ecg"
        case .tilt: return "arrow.up.and.down"
        case .shuttle: return "arrow.left.and.right"
        }
    }

    public var supportsColor: Bool {
        switch self {
        case .off, .colourful, .spectrum: return false
        default: return true
        }
    }

    public var supportsSpeed: Bool {
        switch self {
        case .off, .staticColor: return false
        default: return true
        }
    }

    /// Only these modes use the left/right direction bit.
    public var supportsDirection: Bool {
        switch self {
        case .scrolling, .rolling, .rotating, .flowing, .tilt: return true
        default: return false
        }
    }

    public var forcesRainbow: Bool { self == .colourful || self == .spectrum }
}

public struct AulaRGB: Codable, Hashable, Sendable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8

    public init(_ r: UInt8, _ g: UInt8, _ b: UInt8) {
        self.r = r; self.g = g; self.b = b
    }

    public static let white = AulaRGB(255, 255, 255)
    public static let off = AulaRGB(0, 0, 0)

    public var red: Double { Double(r) / 255 }
    public var green: Double { Double(g) / 255 }
    public var blue: Double { Double(b) / 255 }

    public var hex: String { String(format: "%02X%02X%02X", r, g, b) }

    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        self.init(UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF))
    }

    /// A hue-based helper used by the per-key presets.
    public static func hue(_ h: Double, saturation: Double = 0.85, value: Double = 1.0) -> AulaRGB {
        let hh = (h.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * 6
        let c = value * saturation
        let x = c * (1 - abs(hh.truncatingRemainder(dividingBy: 2) - 1))
        let m = value - c
        let (r, g, b): (Double, Double, Double)
        switch hh {
        case 0..<1: (r, g, b) = (c, x, 0)
        case 1..<2: (r, g, b) = (x, c, 0)
        case 2..<3: (r, g, b) = (0, c, x)
        case 3..<4: (r, g, b) = (0, x, c)
        case 4..<5: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        return AulaRGB(UInt8((r + m) * 255), UInt8((g + m) * 255), UInt8((b + m) * 255))
    }
}

public struct LightingConfig: Codable, Hashable, Sendable {
    public var mode: LightingMode
    public var color: AulaRGB
    public var brightness: UInt8  // 0...5
    public var speed: UInt8       // 0...5
    public var direction: UInt8   // 0...1
    public var colorful: Bool

    public init(
        mode: LightingMode = .rolling,
        color: AulaRGB = AulaRGB(255, 176, 32),
        brightness: UInt8 = 5,
        speed: UInt8 = 3,
        direction: UInt8 = 0,
        colorful: Bool = false
    ) {
        self.mode = mode
        self.color = color
        self.brightness = min(brightness, 5)
        self.speed = min(speed, 5)
        self.direction = min(direction, 1)
        self.colorful = colorful
    }

    public static let `default` = LightingConfig()
}

public struct DeviceOptions: Codable, Hashable, Sendable {
    /// Sleep after inactivity: 0 never, 1 one minute, 2 five minutes, 3 thirty minutes.
    public var sleep: UInt8
    /// Key response / debounce level 1...5.
    public var response: UInt8
    /// 0 = FN works while held, 1 = tap FN to toggle.
    public var fnToggle: UInt8
    public var lockAltTab: Bool
    public var lockAltF4: Bool
    public var lockWin: Bool

    public init(
        sleep: UInt8 = 0,
        response: UInt8 = 1,
        fnToggle: UInt8 = 0,
        lockAltTab: Bool = false,
        lockAltF4: Bool = false,
        lockWin: Bool = false
    ) {
        self.sleep = min(sleep, 3)
        self.response = min(max(response, 1), 5)
        self.fnToggle = min(fnToggle, 1)
        self.lockAltTab = lockAltTab
        self.lockAltF4 = lockAltF4
        self.lockWin = lockWin
    }

    public static let `default` = DeviceOptions()
}
