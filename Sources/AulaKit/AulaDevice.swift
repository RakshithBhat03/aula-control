import Foundation

/// High-level commands for the AULA F108 Pro over the wired configuration
/// interface. The keyboard is write-only: it has no command to read back the
/// current lighting, remaps or macros, so the app's local state is the source
/// of truth and every apply re-sends the complete table.
public final class AulaDevice {
    public let transport: AulaTransport
    public var commandDelay: TimeInterval
    public var log: ((String) -> Void)?

    public init(transport: AulaTransport, commandDelay: TimeInterval = F108.commandDelay) {
        self.transport = transport
        self.commandDelay = commandDelay
    }

    public func close() {
        transport.close()
    }

    // MARK: - Primitives

    private func sleep() {
        if commandDelay > 0 { Thread.sleep(forTimeInterval: commandDelay) }
    }

    private func hex(_ bytes: ArraySlice<UInt8>) -> String {
        bytes.prefix(20).map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    @discardableResult
    public func command(_ payload: [UInt8], readback: Bool = true) throws -> [UInt8]? {
        var report = [UInt8](repeating: 0, count: F108.reportSize)
        report.replaceSubrange(0..<min(payload.count, report.count), with: payload.prefix(report.count))
        log?("TX " + hex(report[...]))
        try transport.setFeature(report)
        sleep()
        guard readback else { return nil }
        let response = try transport.getFeature()
        log?("RX " + hex(response[...]))
        // Firmware ACKs by setting bit 0 of byte 3 for 04 xx commands.
        if report[0] == 0x04, response.count > 3, response[3] != 0x01 {
            log?("warning: no ACK for \(String(format: "%02X %02X", report[0], report[1]))")
        }
        sleep()
        return response
    }

    public func begin() throws {
        try command([0x04, 0x18])
    }

    public func apply() throws {
        try command([0x04, 0x02])
    }

    public func finalize(readback: Bool = false) throws {
        try command([0x04, 0xF0], readback: readback)
    }

    /// Sends a large buffer as 64-byte feature reports. Optionally performs the
    /// single GET_REPORT readback the firmware requires after the last packet.
    public func sendBuffer(_ data: [UInt8], readbackAfter: Bool) throws {
        guard !data.isEmpty else { return }
        var index = 0
        var packet = 0
        while index < data.count {
            let end = min(index + F108.reportSize, data.count)
            var report = [UInt8](repeating: 0, count: F108.reportSize)
            report.replaceSubrange(0..<(end - index), with: data[index..<end])
            try transport.setFeature(report)
            sleep()
            index = end
            packet += 1
            if packet % 8 == 0 { log?("… \(packet) packets") }
        }
        if readbackAfter {
            _ = try transport.getFeature()
            sleep()
        }
    }

    private func complete(_ data: [UInt8], readbackAfter: Bool = false, finalReadback: Bool = false) throws {
        try begin()
        try sendBuffer(data, readbackAfter: readbackAfter)
        try apply()
        try finalize(readback: finalReadback)
    }

    // MARK: - Lighting

    public func setLighting(_ config: LightingConfig) throws {
        guard let mode = LightingMode(rawValue: config.mode.rawValue) else {
            throw AulaError.malformed("unknown lighting mode \(config.mode.rawValue)")
        }
        try begin()

        var initCommand = [UInt8](repeating: 0, count: F108.reportSize)
        initCommand[0] = 0x04
        initCommand[1] = 0x13
        initCommand[8] = 0x01
        try command(initCommand)

        var data = [UInt8](repeating: 0, count: F108.reportSize)
        data[0] = UInt8(mode.rawValue)
        if mode != .off {
            data[1] = config.color.r
            data[2] = config.color.g
            data[3] = config.color.b
            data[8] = config.colorful ? 0x01 : 0x00
            data[9] = min(config.brightness, 5)
            data[10] = min(config.speed, 5)
            data[11] = min(config.direction, 1)
        }
        data[14] = 0x55
        data[15] = 0xAA
        try command(data, readback: false)

        try apply()
        try finalize(readback: false)
    }

    /// Sets the whole per-key RGB frame. Keys absent from `colors` are dark.
    /// Brightness is the global LED brightness (0...5).
    public func setPerKey(_ colors: [UInt8: AulaRGB], brightness: UInt8 = 5) throws {
        let level = min(brightness, 5)

        // Preamble: user-light mode + global brightness.
        try begin()
        var initCommand = [UInt8](repeating: 0, count: F108.reportSize)
        initCommand[0] = 0x04
        initCommand[1] = 0x13
        initCommand[8] = 0x01
        try command(initCommand)

        var preamble = [UInt8](repeating: 0, count: F108.reportSize)
        preamble[0] = 0x80
        preamble[9] = level
        preamble[14] = 0x55
        preamble[15] = 0xAA
        try command(preamble, readback: false)
        try apply()
        try finalize(readback: false)

        // Per-key table: 144 slots × (index, r, g, b), trailer 55 AA.
        try begin()
        var keyInit = [UInt8](repeating: 0, count: F108.reportSize)
        keyInit[0] = 0x04
        keyInit[1] = 0x23
        keyInit[8] = 0x09
        try command(keyInit)

        var table = [UInt8](repeating: 0, count: 0x240)
        for (index, color) in colors {
            let offset = Int(index) * 4
            guard index > 0, offset + 3 < table.count - 2 else { continue }
            table[offset] = index
            table[offset + 1] = color.r
            table[offset + 2] = color.g
            table[offset + 3] = color.b
        }
        table[table.count - 2] = 0x55
        table[table.count - 1] = 0xAA
        try sendBuffer(table, readbackAfter: true)

        try apply()
        try finalize(readback: true)
    }

    // MARK: - Remapping

    public func setRemap(_ map: KeyRemapMap, fnLayer: Bool = false) throws {
        let table = RemapTable.encode(map)
        try begin()

        var initCommand = [UInt8](repeating: 0, count: F108.reportSize)
        initCommand[0] = 0x04
        initCommand[1] = fnLayer ? 0x27 : 0x11
        initCommand[8] = 0x09
        try command(initCommand)

        try sendBuffer(table, readbackAfter: false)
        try apply()
        try finalize(readback: true)
    }

    public func resetRemap(fnLayer: Bool = false) throws {
        try setRemap([:], fnLayer: fnLayer)
    }

    // MARK: - Macros

    /// Sends the complete macro bank. Remap slots that reference macros must be
    /// sent separately with `setRemap`.
    public func setMacros(_ macros: [Macro]) throws {
        guard macros.count <= 100 else {
            throw AulaError.malformed("the keyboard supports at most 100 macros")
        }
        let required = MacroTable.headerSize + macros.reduce(0) { partial, macro in
            partial + 8 + MacroTable.encodedEvents(macro.steps).count
        }
        guard required <= MacroTable.maxSize - 2 else {
            throw AulaError.malformed("macro bank is \(required) bytes; the keyboard limit is \(MacroTable.maxSize - 2)")
        }
        let table = MacroTable.encode(macros)
        let reportCount = MacroTable.reportCount(for: table)

        try command([0x04, 0x19])

        var header = [UInt8](repeating: 0, count: F108.reportSize)
        header[0] = 0x04
        header[1] = 0x15
        header[8] = reportCount
        try command(header)

        try sendBuffer(table, readbackAfter: false)
        try apply()
    }

    // MARK: - Device options

    public func setOptions(_ options: DeviceOptions) throws {
        try begin()

        var initCommand = [UInt8](repeating: 0, count: F108.reportSize)
        initCommand[0] = 0x04
        initCommand[1] = 0x17
        initCommand[2] = 0x01
        initCommand[8] = 0x01
        try command(initCommand)

        var data = [UInt8](repeating: 0, count: F108.reportSize)
        data[0] = 0x00
        data[1] = 0x01
        data[2] = options.lockAltTab ? 0x01 : 0x00
        data[3] = options.lockAltF4 ? 0x01 : 0x00
        data[4] = options.lockWin ? 0x01 : 0x00
        data[5] = options.fnToggle
        data[6] = options.sleep
        data[7] = 0x00
        data[8] = min(max(options.response, 1), 5)
        // The options packet uses the strict little-endian marker (AA 55), like
        // the remap/macro tables. Lighting/clock use the vendor's 55 AA form.
        data[62] = 0xAA
        data[63] = 0x55
        try command(data, readback: false)

        try apply()
    }

    // MARK: - Clock

    public func syncClock(_ date: Date = Date(), calendar: Calendar = .current) throws {        let parts = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .weekday], from: date
        )
        try begin()

        var initCommand = [UInt8](repeating: 0, count: F108.reportSize)
        initCommand[0] = 0x04
        initCommand[1] = 0x28
        initCommand[8] = 0x01
        try command(initCommand)

        var data = [UInt8](repeating: 0, count: F108.reportSize)
        data[1] = 0x01
        data[2] = 0x5A
        data[3] = UInt8((parts.year ?? 2000) % 100)
        data[4] = UInt8(parts.month ?? 1)
        data[5] = UInt8(parts.day ?? 1)
        data[6] = UInt8(parts.hour ?? 0)
        data[7] = UInt8(parts.minute ?? 0)
        data[8] = UInt8(parts.second ?? 0)
        data[10] = UInt8((parts.weekday ?? 1) - 1)
        data[62] = 0x55
        data[63] = 0xAA
        try command(data)

        try apply()
    }

    // MARK: - Push everything

    /// Sends only the begin handshake and a finalize; changes nothing. Useful
    /// for checking that the wired config interface acknowledges commands.
    public func verify() throws -> Bool {
        let response = try command([0x04, 0x18])
        try finalize(readback: false)
        return response.map { $0.count > 3 && $0[3] == 0x01 } ?? false
    }

    /// Re-sends the complete persisted configuration. Macros first, then the
    /// remap tables that can reference them, then lighting and options.
    public func pushAll(_ state: AulaState) throws {
        if !state.macros.isEmpty {
            try setMacros(state.macros)
        }
        if !state.keymap.isEmpty {
            try setRemap(state.keymap, fnLayer: false)
        }
        if !state.fnKeymap.isEmpty {
            try setRemap(state.fnKeymap, fnLayer: true)
        }
        try setLighting(state.lighting)
        if !state.perKey.isEmpty {
            try setPerKey(state.perKeyColors(), brightness: state.perKeyBrightness)
        }
        try setOptions(state.options)
    }
}
