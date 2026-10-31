import Foundation
import AulaKit
import IOKit.hid

// AULA Control — command line companion for the F108 Pro.
// Every command supports --dry-run, which prints the exact HID reports that
// would be sent without touching the keyboard.

let arguments = Array(CommandLine.arguments.dropFirst())

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(("error: " + message + "\n").data(using: .utf8)!)
    exit(1)
}

func usage() -> Never {
    print("""
    AULA Control CLI — configure an AULA F108 Pro from macOS

    USAGE
      aula status                       Show connection and protocol availability
      aula probe                        List AULA HID interfaces and usage pages
      aula light <mode> [options]       Set a backlight effect
      aula perkey [options]             Set per-key RGB
      aula remap [options]              Set the onboard keymap (normal or FN layer)
      aula macro --text "..."           Upload a typing macro
      aula options [options]            Sleep, debounce, FN toggle, key locks
      aula clock                        Sync the LCD clock
      aula verify                       Handshake with the wired configuration interface
      aula push                         Push the saved app configuration
      aula state                        Print the saved configuration path and JSON

    COMMON
      --dry-run                         Print HID reports; do not open the keyboard
      --verbose                         Print protocol traffic

    LIGHTING
      aula light static --color FF8800 --brightness 4
      aula light breath --color 00C8FF --speed 3
      aula light rainbow  (colourful mode)
      Modes: off static single-on single-off glittering falling colourful breath
             spectrum outward scrolling rolling rotating explode launch ripples
             flowing pulsating tilt shuttle

    PER-KEY
      aula perkey --all 101418 --key esc=FF3020 --key space=50C8FF --brightness 5

    REMAP
      aula remap --preset mac
      aula remap --set capslock=ctrl --set lalt=cmd
      aula remap --set caps=combo:cmd+c --set f1=media:volup
      aula remap --fn --set f1=media:play
      aula remap --reset

    OPTIONS
      aula options --sleep 5 --response 3 --fn-toggle --lock-win
    """)
    exit(0)
}

func flag(_ name: String, in args: [String]) -> Bool {
    args.contains("--" + name)
}

func value(_ name: String, in args: [String]) -> String? {
    guard let index = args.firstIndex(of: "--" + name), index + 1 < args.count else { return nil }
    return args[index + 1]
}

func values(_ name: String, in args: [String]) -> [String] {
    var result: [String] = []
    for (index, arg) in args.enumerated() where arg == "--" + name && index + 1 < args.count {
        result.append(args[index + 1])
    }
    return result
}

func positional(_ args: [String]) -> [String] {
    var result: [String] = []
    var skip = false
    for arg in args {
        if skip { skip = false; continue }
        if arg.hasPrefix("--") { skip = true; continue }
        result.append(arg)
    }
    return result
}

func parseUInt8(_ string: String, _ label: String) -> UInt8 {
    guard let value = Int(string), (0...255).contains(value) else {
        fail("\(label) must be 0...255, got \(string)")
    }
    return UInt8(value)
}

func color(_ string: String) -> AulaRGB {
    guard let color = AulaRGB(hex: string) else { fail("invalid color '\(string)' (expected RRGGBB)") }
    return color
}

func mode(_ string: String) -> LightingMode {
    let normalized = string.lowercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
    if let value = Int(string), let mode = LightingMode(rawValue: value) { return mode }
    if normalized == "rainbow" { return .colourful }
    if let mode = LightingMode.allCases.first(where: {
        $0.name.lowercased().replacingOccurrences(of: " ", with: "") == normalized
    }) {
        return mode
    }
    fail("unknown lighting mode '\(string)'")
}

func printHex(_ transport: RecordingTransport) {
    print("\nHID reports (\(transport.sent.count) feature reports, 64 bytes each):")
    for (index, packet) in transport.sent.enumerated() {
        let hex = packet.prefix(20).map { String(format: "%02X", $0) }.joined(separator: " ")
        print(String(format: "  %02d  %@", index, hex))
    }
    print("\nDry run only — no keyboard was opened.")
}

func makeDevice(dryRun: Bool) -> (AulaDevice, RecordingTransport?) {
    if dryRun {
        let transport = RecordingTransport()
        let device = AulaDevice(transport: transport, commandDelay: 0)
        if flag("verbose", in: arguments) {
            device.log = { print("    " + $0) }
        }
        return (device, transport)
    }
    do {
        let device = try AulaDiscovery.openWired()
        if flag("verbose", in: arguments) {
            device.log = { print("    " + $0) }
        }
        return (device, nil)
    } catch {
        fail(error.localizedDescription)
    }
}

func finish(_ transport: RecordingTransport?, dryRun: Bool) {
    if let transport, dryRun { printHex(transport) }
    print("Done.")
}

func connectionStatus() {
    let info = AulaDiscovery.detect()
    print("AULA Control")
    print("  Connection       : \(info.kind.title)")
    if info.kind != .absent {
        print("  Product          : \(info.product)")
        print("  Transport        : \(info.transport)")
        if let uid = info.uniqueID { print("  Device ID        : \(uid)") }
    }
    print("  Hardware config  : \(info.kind.supportsHardwareConfig ? "available" : "unavailable")")
    if info.kind == .bluetooth {
        print("  → Settings need USB-C. Connect the cable and press Fn + 4.")
        print("  → macOS-level remapping works over Bluetooth in the app.")
    } else if info.kind == .dongle {
        print("  → The 2.4 GHz dongle only supports reduced settings; use USB-C for everything.")
    } else if info.kind == .absent {
        print("  → Connect the keyboard with USB-C (Fn + 4) or Bluetooth.")
    }
    let devices = AulaDiscovery.allAulaDevices()
    print("  HID services     : \(devices.count)")
}

func probe() {
    let devices = AulaDiscovery.allAulaDevices()
    if devices.isEmpty {
        print("No AULA HID services found. Connect USB-C or Bluetooth and retry.")
        return
    }
    for (index, device) in devices.enumerated() {
        func prop(_ key: String) -> String {
            if let value = IOHIDDeviceGetProperty(device, key as CFString) as? String { return value }
            if let value = IOHIDDeviceGetProperty(device, key as CFString) as? Int { return String(value) }
            return "—"
        }
        print("[\(index)] \(prop(kIOHIDProductKey))")
        print("     VID/PID        \(prop(kIOHIDVendorIDKey)):\(prop(kIOHIDProductIDKey))")
        print("     transport      \(prop(kIOHIDTransportKey))")
        print("     primary usage  page \(prop(kIOHIDPrimaryUsagePageKey)) usage \(prop(kIOHIDPrimaryUsageKey))")
        if let pairs = IOHIDDeviceGetProperty(device, kIOHIDDeviceUsagePairsKey as CFString) as? [[String: Int]] {
            let text = pairs.map { String(format: "%04X:%02X", $0[kIOHIDDeviceUsagePageKey] ?? -1, $0[kIOHIDDeviceUsageKey] ?? -1) }
            print("     usage pairs    \(text.joined(separator: ", "))")
        }
        if let maxFeature = IOHIDDeviceGetProperty(device, kIOHIDMaxFeatureReportSizeKey as CFString) as? Int {
            print("     feature size   \(maxFeature)")
        }
        print("")
    }
}

func lightCommand(_ args: [String]) {
    let rest = positional(args)
    let modeValue = value("mode", in: args) ?? rest.first ?? "static"
    let selected = mode(modeValue)
    var config = LightingConfig(
        mode: selected,
        color: color(value("color", in: args) ?? "FFB020"),
        brightness: UInt8(min(5, max(0, Int(value("brightness", in: args) ?? "4") ?? 4))),
        speed: UInt8(min(5, max(0, Int(value("speed", in: args) ?? "3") ?? 3))),
        direction: UInt8(min(1, max(0, Int(value("direction", in: args) ?? "0") ?? 0))),
        colorful: flag("rainbow", in: args) || selected.forcesRainbow
    )
    if selected.forcesRainbow { config.colorful = true }
    if selected == .off {
        config = LightingConfig(mode: .off)
    }

    let dryRun = flag("dry-run", in: args)
    let (device, recorder) = makeDevice(dryRun: dryRun)
    do {
        try device.setLighting(config)
        finish(recorder, dryRun: dryRun)
        if !dryRun { device.close() }
    } catch { fail(error.localizedDescription) }
}

func perKeyCommand(_ args: [String]) {
    var colors: [String: AulaRGB] = [:]
    if let all = value("all", in: args) {
        let base = color(all)
        for key in KeyLayout.f108Pro.keys { colors[key.name] = base }
    }
    for pair in values("key", in: args) {
        let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { fail("expected --key name=RRGGBB, got '\(pair)'") }
        guard KeyLayout.f108Pro.key(named: parts[0]) != nil else { fail("unknown key '\(parts[0])'") }
        colors[parts[0]] = color(parts[1])
    }
    guard !colors.isEmpty else { fail("provide --all RRGGBB and/or --key name=RRGGBB") }

    let brightness = UInt8(min(5, max(0, Int(value("brightness", in: args) ?? "5") ?? 5)))
    let dryRun = flag("dry-run", in: args)
    let (device, recorder) = makeDevice(dryRun: dryRun)
    let lightMap = Dictionary(uniqueKeysWithValues: colors.compactMap { name, color -> (UInt8, AulaRGB)? in
        guard let key = KeyLayout.f108Pro.key(named: name) else { return nil }
        return (key.light, color)
    })
    do {
        try device.setPerKey(lightMap, brightness: brightness)
        finish(recorder, dryRun: dryRun)
        if !dryRun { device.close() }
    } catch { fail(error.localizedDescription) }
}

func parseAction(_ string: String) -> KeyAction {
    let lower = string.lowercased()
    switch lower {
    case "none", "default", "reset": return .none
    case "disabled", "disable", "off": return .disabled
    case "ctrl", "control", "lctrl": return .leftControl
    case "rctrl", "rightctrl": return .rightControl
    case "shift", "lshift": return .leftShift
    case "rshift": return .rightShift
    case "alt", "option", "opt", "lalt": return .leftOption
    case "ralt", "roption": return .rightOption
    case "cmd", "command", "win", "lwin": return .leftCommand
    case "rcmd", "rwin": return .rightCommand
    default: break
    }

    if lower.hasPrefix("media:") {
        let name = String(lower.dropFirst("media:".count))
        let aliases: [String: UInt16] = [
            "play": 0xCD, "playpause": 0xCD, "stop": 0xB7, "prev": 0xB6, "next": 0xB5,
            "volup": 0xE9, "voldown": 0xEA, "mute": 0xE2, "calc": 0x192,
            "browser": 0x223, "search": 0x221,
        ]
        guard let usage = aliases[name] else { fail("unknown media action '\(name)'") }
        return .consumer(usage)
    }

    if lower.hasPrefix("combo:") {
        let expression = String(lower.dropFirst("combo:".count))
        let parts = expression.split(separator: "+").map(String.init)
        guard parts.count >= 2 else { fail("combo must look like combo:cmd+c") }
        var modifiers: UInt8 = 0
        for modifier in parts.dropLast() {
            switch modifier {
            case "ctrl", "control": modifiers |= ModifierBits.leftControl
            case "shift": modifiers |= ModifierBits.leftShift
            case "alt", "option", "opt": modifiers |= ModifierBits.leftOption
            case "cmd", "command", "win": modifiers |= ModifierBits.leftCommand
            case "rctrl": modifiers |= ModifierBits.rightControl
            case "rshift": modifiers |= ModifierBits.rightShift
            case "ralt", "roption": modifiers |= ModifierBits.rightOption
            case "rcmd", "rwin": modifiers |= ModifierBits.rightCommand
            default: fail("unknown modifier '\(modifier)'")
            }
        }
        let keyName = parts.last!
        guard let key = KeyLayout.f108Pro.key(named: keyName) else { fail("unknown key '\(keyName)' in combo") }
        return .key(usage: key.usage, modifiers: modifiers)
    }

    if lower.hasPrefix("macro:") {
        let index = Int(lower.dropFirst("macro:".count)) ?? 0
        return .macro(index: UInt8(min(max(index, 0), 99)), mode: 0, count: 0)
    }

    if lower == "capslock" { return .special(0x01, 0x02) }
    if lower == "numlock" { return .special(0x01, 0x01) }
    if lower == "scrolllock" { return .special(0x01, 0x04) }
    if lower == "insert" { return .special(0x01, 0x03) }
    if lower == "calculator" { return .special(0x03, 0x01) }
    if lower == "lock" { return .special(0x03, 0xFF) }

    guard let key = KeyLayout.f108Pro.key(named: lower) else {
        fail("unknown remap target '\(string)'")
    }
    return .key(usage: key.usage)
}

func remapCommand(_ args: [String]) {
    var map: KeyRemapMap = [:]
    if flag("reset", in: args) {
        map = [:]
    } else if let preset = value("preset", in: args)?.lowercased() {
        switch preset {
        case "mac": map = RemapPresets.mac
        case "windows": map = RemapPresets.windows
        case "caps": map = RemapPresets.capsToControl
        case "wasd": map = RemapPresets.wasdArrows
        default: fail("unknown preset '\(preset)' (mac, windows, caps, wasd)")
        }
    }
    for pair in values("set", in: args) {
        let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { fail("expected --set source=target, got '\(pair)'") }
        let source = parts[0].lowercased()
        guard KeyLayout.f108Pro.key(named: source) != nil else { fail("unknown source key '\(source)'") }
        map[source] = parseAction(parts[1])
    }
    if map.isEmpty && !flag("reset", in: args) && value("preset", in: args) == nil {
        fail("provide --preset, --set, or --reset")
    }

    let fnLayer = flag("fn", in: args)
    let dryRun = flag("dry-run", in: args)
    let (device, recorder) = makeDevice(dryRun: dryRun)
    do {
        try device.setRemap(map, fnLayer: fnLayer)
        finish(recorder, dryRun: dryRun)
        if !dryRun { device.close() }
    } catch { fail(error.localizedDescription) }
}

func macroCommand(_ args: [String]) {
    let text = value("text", in: args) ?? "Hello from AULA Control"
    let name = value("name", in: args) ?? "CLI macro"
    let macro = Macro.typing(text, name: name)
    let dryRun = flag("dry-run", in: args)
    let (device, recorder) = makeDevice(dryRun: dryRun)
    do {
        try device.setMacros([macro])
        finish(recorder, dryRun: dryRun)
        if !dryRun { device.close() }
    } catch { fail(error.localizedDescription) }
}

func optionsCommand(_ args: [String]) {
    var options = DeviceOptions()
    if let sleepValue = value("sleep", in: args) {
        switch sleepValue.lowercased() {
        case "never", "0": options.sleep = 0
        case "1": options.sleep = 1
        case "5": options.sleep = 2
        case "30": options.sleep = 3
        default: fail("--sleep must be never, 1, 5 or 30")
        }
    }
    if let response = value("response", in: args) {
        options.response = UInt8(min(5, max(1, Int(response) ?? 1)))
    }
    if flag("fn-toggle", in: args) { options.fnToggle = 1 }
    options.lockWin = flag("lock-win", in: args)
    options.lockAltTab = flag("lock-alt-tab", in: args)
    options.lockAltF4 = flag("lock-alt-f4", in: args)

    let dryRun = flag("dry-run", in: args)
    let (device, recorder) = makeDevice(dryRun: dryRun)
    do {
        try device.setOptions(options)
        finish(recorder, dryRun: dryRun)
        if !dryRun { device.close() }
    } catch { fail(error.localizedDescription) }
}

func clockCommand(_ args: [String]) {
    let dryRun = flag("dry-run", in: args)
    let (device, recorder) = makeDevice(dryRun: dryRun)
    do {
        try device.syncClock()
        finish(recorder, dryRun: dryRun)
        if !dryRun { device.close() }
    } catch { fail(error.localizedDescription) }
}

func verifyCommand(_ args: [String]) {
    let dryRun = flag("dry-run", in: args)
    let (device, recorder) = makeDevice(dryRun: dryRun)
    do {
        let ack = try device.verify()
        if dryRun {
            finish(recorder, dryRun: true)
        } else {
            device.close()
            if ack {
                print("Configuration interface responded with an ACK. Hardware control is ready.")
            } else {
                fail("The device opened but did not acknowledge the begin command.")
            }
        }
    } catch { fail(error.localizedDescription) }
}

func pushCommand(_ args: [String]) {
    let store = AulaStore()
    let state = store.load()
    let dryRun = flag("dry-run", in: args)
    let (device, recorder) = makeDevice(dryRun: dryRun)
    do {
        try device.pushAll(state)
        finish(recorder, dryRun: dryRun)
        if !dryRun { device.close() }
    } catch { fail(error.localizedDescription) }
}

func stateCommand() {
    let store = AulaStore()
    let state = store.load()
    print("State file: \(store.url.path)")
    if let json = try? store.exportJSON(state) { print(json) }
}

guard let command = arguments.first else { usage() }
let rest = Array(arguments.dropFirst())

switch command {
case "status": connectionStatus()
case "probe": probe()
case "light": lightCommand(rest)
case "perkey", "per-key": perKeyCommand(rest)
case "remap": remapCommand(rest)
case "macro", "macros": macroCommand(rest)
case "options": optionsCommand(rest)
case "clock": clockCommand(rest)
case "verify": verifyCommand(rest)
case "push": pushCommand(rest)
case "state": stateCommand()
case "help", "--help", "-h": usage()
default: fail("unknown command '\(command)'. Run 'aula help'.")
}
