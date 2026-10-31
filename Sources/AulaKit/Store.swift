import Foundation

public struct MacRemapSettings: Codable, Hashable, Sendable {
    public var enabled: Bool
    /// When true the event tap only acts on events coming from the AULA.
    public var onlyThisKeyboard: Bool
    public var map: KeyRemapMap

    public init(enabled: Bool = false, onlyThisKeyboard: Bool = true, map: KeyRemapMap = [:]) {
        self.enabled = enabled
        self.onlyThisKeyboard = onlyThisKeyboard
        self.map = map
    }
}

public struct AulaState: Codable, Sendable {
    public var lighting: LightingConfig
    /// Per-key colors keyed by key name. Only painted keys are stored.
    public var perKey: [String: AulaRGB]
    public var perKeyBrightness: UInt8
    public var keymap: KeyRemapMap
    public var fnKeymap: KeyRemapMap
    public var macros: [Macro]
    public var options: DeviceOptions
    public var macRemap: MacRemapSettings
    public var autoApplyOnConnect: Bool

    public init(
        lighting: LightingConfig = .default,
        perKey: [String: AulaRGB] = [:],
        perKeyBrightness: UInt8 = 5,
        keymap: KeyRemapMap = [:],
        fnKeymap: KeyRemapMap = [:],
        macros: [Macro] = [],
        options: DeviceOptions = .default,
        macRemap: MacRemapSettings = .init(),
        autoApplyOnConnect: Bool = false
    ) {
        self.lighting = lighting
        self.perKey = perKey
        self.perKeyBrightness = min(perKeyBrightness, 5)
        self.keymap = keymap
        self.fnKeymap = fnKeymap
        self.macros = macros
        self.options = options
        self.macRemap = macRemap
        self.autoApplyOnConnect = autoApplyOnConnect
    }

    public func perKeyColors() -> [UInt8: AulaRGB] {
        let layout = KeyLayout.f108Pro
        var result: [UInt8: AulaRGB] = [:]
        for (name, color) in perKey {
            if let key = layout.key(named: name) {
                result[key.light] = color
            }
        }
        return result
    }

    /// Convenience for previews and fresh installs.
    public static let sample = AulaState(
        lighting: .default,
        perKey: [
            "esc": AulaRGB(255, 60, 48),
            "w": AulaRGB(255, 190, 64),
            "a": AulaRGB(255, 190, 64),
            "s": AulaRGB(255, 190, 64),
            "d": AulaRGB(255, 190, 64),
            "space": AulaRGB(80, 200, 255),
        ],
        keymap: RemapPresets.mac,
        macros: [
            Macro(
                name: "Paste as plain text",
                steps: [
                    .delay(milliseconds: 20),
                    .key(usage: 0x06, down: true),
                    .key(usage: 0x06, down: false),
                    .delay(milliseconds: 45),
                    .key(usage: 0x1E, down: true),
                    .key(usage: 0x1E, down: false),
                    .delay(milliseconds: 20),
                ]
            )
        ]
    )
}

public final class AulaStore {
    public let url: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(url: URL? = nil) {
        if let url {
            self.url = url
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
            self.url = base
                .appendingPathComponent("AULA Control", isDirectory: true)
                .appendingPathComponent("state.json")
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func load() -> AulaState {
        guard let data = try? Data(contentsOf: url),
              let state = try? decoder.decode(AulaState.self, from: data) else {
            return AulaState()
        }
        return state
    }

    public func save(_ state: AulaState) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(state)
        try data.write(to: url, options: .atomic)
    }

    public func exportJSON(_ state: AulaState) throws -> String {
        String(data: try encoder.encode(state), encoding: .utf8) ?? "{}"
    }

    public func importJSON(_ string: String) throws -> AulaState {
        guard let data = string.data(using: .utf8) else {
            throw AulaError.malformed("not UTF-8")
        }
        return try decoder.decode(AulaState.self, from: data)
    }
}
