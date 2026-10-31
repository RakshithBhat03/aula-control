import XCTest
import CoreGraphics
@testable import AulaKit

final class KeyLayoutTests: XCTestCase {
    func testProductNameMatching() {
        XCTAssertTrue(AulaDiscovery.looksLikeF108Pro("AULA F108Pro"))
        XCTAssertTrue(AulaDiscovery.looksLikeF108Pro("AULA-F108Pro-1"))
        XCTAssertTrue(AulaDiscovery.looksLikeF108Pro("F108Pro Dongle"))
        XCTAssertFalse(AulaDiscovery.looksLikeF108Pro("Karabiner DriverKit VirtualHIDKeyboard"))
        XCTAssertFalse(AulaDiscovery.looksLikeF108Pro("Apple Internal Keyboard"))
    }

    func testHas104PhysicalKeysAndUniqueLights() {
        let layout = KeyLayout.f108Pro
        XCTAssertEqual(layout.keys.count, 104)
        XCTAssertEqual(Set(layout.keys.map(\.name)).count, 104)
        XCTAssertEqual(Set(layout.keys.map(\.light)).count, 104)
        XCTAssertTrue(layout.keys.allSatisfy { $0.light > 0 && $0.light <= 123 })
        XCTAssertTrue(layout.keys.allSatisfy { $0.usage > 0 })
    }

    func testModifierAndArrowMappings() {
        let layout = KeyLayout.f108Pro
        XCTAssertEqual(layout.key(named: "capslock")?.light, 55)
        XCTAssertEqual(layout.key(named: "capslock")?.usage, 0x39)
        XCTAssertEqual(layout.key(named: "lwin")?.macKeyCode, 55)
        XCTAssertEqual(layout.key(named: "left")?.macKeyCode, 123)
        XCTAssertEqual(KeyLayout.usage(forMacKeyCode: 0), 0x04)
        XCTAssertEqual(KeyLayout.macKeyCode(forUsage: 0x39), 57)
    }

    func testAllMacMappingsAreBidirectional() {
        for key in KeyLayout.f108Pro.keys where key.usage != 0xAF {
            guard let mac = key.macKeyCode else {
                XCTFail("No macOS keycode for \(key.name)")
                continue
            }
            XCTAssertEqual(
                KeyLayout.usage(forMacKeyCode: mac), key.usage,
                "round trip failed for \(key.name) (usage \(key.usage), keycode \(mac))"
            )
        }
    }
}

final class ProtocolEncodingTests: XCTestCase {
    private func device() -> (AulaDevice, RecordingTransport) {
        let transport = RecordingTransport()
        let device = AulaDevice(transport: transport, commandDelay: 0)
        return (device, transport)
    }

    func testLightingSequenceAndPayload() throws {
        let (device, transport) = device()
        try device.setLighting(LightingConfig(
            mode: .staticColor,
            color: AulaRGB(0x12, 0x34, 0x56),
            brightness: 4, speed: 2, direction: 1, colorful: false
        ))

        XCTAssertEqual(transport.sent.count, 5)
        XCTAssertEqual(Array(transport.sent[0].prefix(2)), [0x04, 0x18])
        XCTAssertEqual(Array(transport.sent[1].prefix(9)), [0x04, 0x13, 0, 0, 0, 0, 0, 0, 0x01])
        let data = transport.sent[2]
        XCTAssertEqual(data[0], 0x01)           // static
        XCTAssertEqual(Array(data[1...3]), [0x12, 0x34, 0x56])
        XCTAssertEqual(data[8], 0)
        XCTAssertEqual(data[9], 4)
        XCTAssertEqual(data[10], 2)
        XCTAssertEqual(data[11], 1)
        XCTAssertEqual(Array(data[14...15]), [0x55, 0xAA])
        XCTAssertEqual(Array(transport.sent[3].prefix(2)), [0x04, 0x02])
        XCTAssertEqual(Array(transport.sent[4].prefix(2)), [0x04, 0xF0])
    }

    func testPerKeyTableHasCorrectSlotAndTrailer() throws {
        let (device, transport) = device()
        try device.setPerKey([56: AulaRGB(10, 20, 30)], brightness: 3)

        // preamble(5) + begin + init + 9 data + apply + finalize = 18
        XCTAssertEqual(transport.sent.count, 18)
        XCTAssertEqual(Array(transport.sent[0].prefix(2)), [0x04, 0x18])
        XCTAssertEqual(transport.sent[1][0], 0x04)
        XCTAssertEqual(transport.sent[1][1], 0x13)
        XCTAssertEqual(transport.sent[2][0], 0x80)
        XCTAssertEqual(transport.sent[2][9], 3)
        XCTAssertEqual(Array(transport.sent[3].prefix(2)), [0x04, 0x02])

        XCTAssertEqual(Array(transport.sent[5].prefix(2)), [0x04, 0x18])
        XCTAssertEqual(transport.sent[6][1], 0x23)
        XCTAssertEqual(transport.sent[6][8], 0x09)

        let table = transport.sent[7..<16].flatMap { $0 }
        XCTAssertEqual(table.count, 576)
        let offset = 56 * 4
        XCTAssertEqual(Array(table[offset..<offset + 4]), [56, 10, 20, 30])
        XCTAssertEqual(Array(table[574...575]), [0x55, 0xAA])
        XCTAssertEqual(transport.sent[16][1], 0x02)
        XCTAssertEqual(transport.sent[17][1], 0xF0)
    }

    func testRemapCapsToControl() throws {
        let (device, transport) = device()
        try device.setRemap(["capslock": .leftControl])

        XCTAssertEqual(Array(transport.sent[0].prefix(2)), [0x04, 0x18])
        XCTAssertEqual(transport.sent[1][1], 0x11)
        XCTAssertEqual(transport.sent[1][8], 0x09)
        let table = transport.sent[2..<11].flatMap { $0 }
        XCTAssertEqual(table.count, 576)
        XCTAssertEqual(Array(table[(55 * 4)..<(55 * 4) + 4]), [0x02, 0x01, 0x00, 0x00])
        XCTAssertEqual(Array(table[574...575]), [0xAA, 0x55])
        XCTAssertEqual(transport.sent[11][1], 0x02)
        XCTAssertEqual(transport.sent[12][1], 0xF0)
    }

    func testRemapConsumerUses16BitUsage() {
        let map: KeyRemapMap = ["capslock": .consumer(0x0192)] // calculator
        let table = RemapTable.encode(map)
        XCTAssertEqual(Array(table[(55 * 4)..<(55 * 4) + 4]), [0x03, 0x92, 0x01, 0x00])
    }

    func testMacroBufferLayout() {
        var macro = Macro(name: "ab")
        macro.appendKey(0x04)
        macro.appendKey(0x05)
        let buffer = MacroTable.encode([macro])

        XCTAssertEqual(buffer.count % 64, 0)
        XCTAssertEqual(Array(buffer[0...3]), [0x90, 0x01, 0x00, 0x00]) // offset 400
        XCTAssertEqual(Array(buffer[400...401]), [28, 0])               // 7 steps × 4 bytes
        XCTAssertEqual(Array(buffer[408...411]), [0x0C, 0x00, 0x00, 0x50])
        XCTAssertEqual(Array(buffer[412...415]), [0, 0, 0x04, 0xB0])
        XCTAssertEqual(Array(buffer[416...419]), [0, 0, 0x04, 0x30])
        XCTAssertEqual(Array(buffer[420...423]), [0x0C, 0x00, 0x00, 0x50])
        XCTAssertEqual(Array(buffer[424...427]), [0, 0, 0x05, 0xB0])
        XCTAssertEqual(Array(buffer[(buffer.count - 2)...]), [0xAA, 0x55])
    }

    func testMouseMacroEncoding() {
        var macro = Macro(name: "click")
        macro.appendMouseClick(button: 2)
        let events = MacroTable.encodedEvents(macro.steps)
        XCTAssertEqual(Array(events[0...3]), [0, 0, 0x04, 0x90]) // right down
        XCTAssertEqual(Array(events[8...11]), [0, 0, 0x04, 0x10]) // right up
    }

    func testMacroSequence() throws {        let (device, transport) = device()
        var macro = Macro(name: "test")
        macro.appendKey(0x04)
        try device.setMacros([macro])

        XCTAssertEqual(Array(transport.sent[0].prefix(2)), [0x04, 0x19])
        XCTAssertEqual(Array(transport.sent[1].prefix(2)), [0x04, 0x15])
        let count = Int(transport.sent[1][8])
        XCTAssertEqual(count, transport.sent.count - 3)
        XCTAssertEqual(transport.sent.last?.prefix(2), [0x04, 0x02])
    }

    func testOptionsPacket() throws {
        let (device, transport) = device()
        try device.setOptions(DeviceOptions(
            sleep: 2, response: 4, fnToggle: 1,
            lockAltTab: true, lockAltF4: false, lockWin: true
        ))

        XCTAssertEqual(Array(transport.sent[0].prefix(2)), [0x04, 0x18])
        XCTAssertEqual(Array(transport.sent[1].prefix(3)), [0x04, 0x17, 0x01])
        XCTAssertEqual(transport.sent[1][8], 0x01)
        let data = transport.sent[2]
        XCTAssertEqual(Array(data[0...8]), [0x00, 0x01, 0x01, 0x00, 0x01, 0x01, 0x02, 0x00, 0x04])
        XCTAssertEqual(Array(data[62...63]), [0xAA, 0x55])
        XCTAssertEqual(Array(transport.sent[3].prefix(2)), [0x04, 0x02])
    }

    func testClockPacket() throws {
        let (device, transport) = device()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(
            year: 2026, month: 10, day: 31, hour: 21, minute: 5, second: 9, weekday: 7
        ))!
        try device.syncClock(date, calendar: calendar)

        let data = transport.sent[2]
        XCTAssertEqual(Array(data[1...8]), [0x01, 0x5A, 26, 10, 31, 21, 5, 9])
        XCTAssertEqual(data[10], 6)
        XCTAssertEqual(Array(data[62...63]), [0x55, 0xAA])
    }

    func testStateJSONRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = AulaStore(url: directory.appendingPathComponent("state.json"))
        var state = AulaState.sample
        state.macros[0].name = "Round trip"
        try store.save(state)
        let loaded = store.load()
        XCTAssertEqual(loaded.macros.first?.name, "Round trip")
        XCTAssertEqual(loaded.keymap["lalt"], .leftCommand)
        XCTAssertEqual(loaded.perKey["esc"], AulaRGB(255, 60, 48))
    }

    func testAllActionSlots() {
        XCTAssertEqual(KeyAction.none.slot, [0x00, 0x00, 0x00, 0x00])
        XCTAssertEqual(KeyAction.leftControl.slot, [0x02, 0x01, 0x00, 0x00])
        XCTAssertEqual(KeyAction.key(usage: 0x06, modifiers: 0x01).slot, [0x02, 0x01, 0x06, 0x00])
        XCTAssertEqual(KeyAction.key(usage: 0xE1, modifiers: 0).slot, [0x02, 0x02, 0x00, 0x00])
        XCTAssertEqual(KeyAction.consumer(0xE9).slot, [0x03, 0xE9, 0x00, 0x00])
        XCTAssertEqual(KeyAction.consumer(0x0192).slot, [0x03, 0x92, 0x01, 0x00])
        XCTAssertEqual(KeyAction.macro(index: 2, mode: 1, count: 3).slot, [0x06, 0x02, 0x01, 0x03])
        XCTAssertEqual(KeyAction.disabled.slot, [0x05, 0x03, 0x00, 0x00])
        XCTAssertEqual(KeyAction.mouse(0x01, 0x00, 0x00).slot, [0x07, 0x01, 0x00, 0x00])
    }

    func testTypingMacroUsesShiftForUppercaseAndSymbols() {
        let macro = Macro.typing("Hi!")
        let text = macro.steps.map(\.displayName).joined(separator: ",")
        XCTAssertTrue(text.contains("⇧ down"))
        XCTAssertTrue(text.contains("H down"))
        XCTAssertTrue(text.contains("! down") || text.contains("1 down"))
    }

    func testOversizedMacroBankIsRejected() {
        let transport = RecordingTransport()
        let device = AulaDevice(transport: transport, commandDelay: 0)
        let huge = Macro(name: "huge", steps: (0..<1000).map { .delay(milliseconds: 1000 + UInt16($0)) })
        XCTAssertThrowsError(try device.setMacros([huge]))
        XCTAssertTrue(transport.sent.isEmpty)
    }

    func testLayoutKeysAreInsideTheDeck() {
        for key in KeyLayout.f108Pro.keys {
            XCTAssertGreaterThanOrEqual(key.x, 0)
            XCTAssertGreaterThanOrEqual(key.y, 0)
            XCTAssertLessThanOrEqual(key.x + key.width, KeyLayout.f108Pro.widthUnits + 0.001)
            XCTAssertLessThanOrEqual(key.y + key.height, KeyLayout.f108Pro.heightUnits + 0.001)
        }
    }
}
