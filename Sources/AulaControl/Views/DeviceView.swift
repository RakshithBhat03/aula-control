import SwiftUI
import AulaKit

struct DeviceView: View {
    @EnvironmentObject var model: AppModel
    @State private var showResetConfirm = false

    private var hardwareReady: Bool { model.canUseHardware || model.isPreview }

    var body: some View {
        PageScroll {
            PageHeader(
                eyebrow: "USB-C",
                title: "Device",
                subtitle: "Connection details, plus power, response and key-lock options stored on the keyboard."
            ) {
                HStack(spacing: 8) {
                    StatusPill(
                        text: model.hardwareStatusText,
                        color: model.connectionColor,
                        icon: model.connection.kind.symbol
                    )
                    Button {
                        model.pushAll()
                    } label: {
                        Label("Apply all", systemImage: "arrow.down.to.line")
                    }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(model.isBusy || !hardwareReady)
                    .help("Re-sends lighting, keymap, macros, per-key colors and options.")
                }
            }

            if model.connection.kind != .wired && !model.isPreview {
                transportNotice
            }

            SplitRow {
                VStack(alignment: .leading, spacing: Theme.gutter) {
                    optionsCard
                    utilitiesCard
                }
            } aside: {
                VStack(alignment: .leading, spacing: Theme.gutter) {
                    connectionCard
                    shortcutsCard
                }
            }
        }
        .confirmationDialog(
            "Reset the onboard keymap?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset \(model.selectedLayer.title)", role: .destructive) {
                model.resetOnboardKeymap()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears every remap on the selected layer and writes an empty table to the keyboard.")
        }
    }

    // MARK: - Transport notice

    private var transportNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Theme.secondary)
            Text("Options on this page write over the USB-C cable. Switch to wired mode with")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.secondary)
            KeyCombo(["Fn", "4"])
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.panelInset)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .fill(Theme.field)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    // MARK: - Firmware options

    private var optionsCard: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeaderBand(
                    "Firmware options",
                    detail: "Saved with your config. Apply writes them to the keyboard."
                )

                GroupLabel("Power and response")
                FormRow("Sleep after inactivity", detail: "Turns the radio off when idle") {
                    SleepSelector(value: Binding(
                        get: { model.state.options.sleep },
                        set: { model.state.options.sleep = $0 }
                    ))
                }
                Hairline()
                FormRow("Key response", detail: "Debounce level, from 1 to 5") {
                    ResponseControl(value: Binding(
                        get: { model.state.options.response },
                        set: { model.state.options.response = $0 }
                    ))
                }
                Hairline()
                KeyedFormRow("Fn tap toggle", detail: "Tap to latch the layer instead of holding", keys: ["Fn"]) {
                    SwitchControl(
                        label: "Fn tap toggle",
                        isOn: Binding(
                            get: { model.state.options.fnToggle == 1 },
                            set: { model.state.options.fnToggle = $0 ? 1 : 0 }
                        )
                    )
                }

                Hairline()
                GroupLabel("Key locks")
                KeyedFormRow("Lock Windows key", detail: "Prevents accidental Start menu presses", keys: ["Win"]) {
                    SwitchControl(
                        label: "Lock Windows key",
                        isOn: Binding(
                            get: { model.state.options.lockWin },
                            set: { model.state.options.lockWin = $0 }
                        )
                    )
                }
                Hairline()
                KeyedFormRow("Lock Alt + Tab", detail: "Disables the task switcher chord", keys: ["Alt", "Tab"]) {
                    SwitchControl(
                        label: "Lock Alt + Tab",
                        isOn: Binding(
                            get: { model.state.options.lockAltTab },
                            set: { model.state.options.lockAltTab = $0 }
                        )
                    )
                }
                Hairline()
                KeyedFormRow("Lock Alt + F4", detail: "Disables the close window chord", keys: ["Alt", "F4"]) {
                    SwitchControl(
                        label: "Lock Alt + F4",
                        isOn: Binding(
                            get: { model.state.options.lockAltF4 },
                            set: { model.state.options.lockAltF4 = $0 }
                        )
                    )
                }

                Hairline()
                HStack(spacing: 12) {
                    Text(model.isPreview ? "Preview mode: commands are simulated." : (hardwareReady ? "Writes over USB-C." : "Connect USB-C to apply."))
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.tertiary)
                    Spacer(minLength: 12)
                    Button {
                        model.applyOptions()
                    } label: {
                        Label("Apply device options", systemImage: "checkmark")
                    }
                    .buttonStyle(AccentButtonStyle(enabled: hardwareReady))
                    .disabled(model.isBusy || !hardwareReady)
                }
                .padding(Theme.panelInset)
            }
        }
    }

    // MARK: - Utilities

    private var utilitiesCard: some View {
        Card(padding: 0, fillHeight: true) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeaderBand("Utilities", detail: "One-off actions on the keyboard.")
                FormRow("Sync LCD clock", detail: "Sends the current date and time to the 240 × 135 screen.") {
                    Button("Sync now") { model.syncClock() }
                        .buttonStyle(GhostButtonStyle())
                        .disabled(model.isBusy || !hardwareReady)
                }
                Hairline()
                FormRow(
                    "Reset onboard keymap",
                    detail: "Clears the \(model.selectedLayer.title.lowercased()) and restores factory behavior."
                ) {
                    Button("Reset…") { showResetConfirm = true }
                        .buttonStyle(GhostButtonStyle(danger: true))
                        .disabled(model.isBusy)
                }
            }
        }
    }

    // MARK: - Connection

    /// Why there's no battery level: USB-C has no battery report; the wireless links read it.
    private var batteryNote: String {
        switch model.connection.kind {
        case .wired: return "Not reported over USB-C"
        case .bluetooth, .dongle: return "Waiting for the keyboard"
        case .absent: return "—"
        }
    }

    private var connectionCard: some View {
        let wired = model.connection.kind == .wired
        let absent = model.connection.kind == .absent
        return Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeaderBand("Connection", detail: "Read from the keyboard's HID services.") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(model.connectionColor)
                            .frame(width: 6, height: 6)
                        Text(model.connection.kind.title)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.secondary)
                    }
                }

                SpecRow("Product") { SpecValue(absent ? "—" : model.connection.product, machine: false) }
                Hairline()
                SpecRow("Transport") { SpecValue(absent ? "—" : model.connection.transport, machine: false) }
                Hairline()
                SpecRow("Battery") {
                    if let level = model.batteryPercent {
                        BatteryIndicator(level: level)
                    } else {
                        Text(batteryNote)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.tertiary)
                    }
                }
                Hairline()
                SpecRow("USB ID") {
                    SpecValue(String(format: "%04X:%04X", model.connection.vendorID, model.connection.productID))
                }
                Hairline()
                SpecRow("Unique ID") { SpecValue(model.connection.uniqueID ?? "—") }
                Hairline()
                SpecRow("HID services") { SpecValue("\(AulaDiscovery.allAulaDevices().count)") }
                Hairline()
                SpecRow("Config interface") {
                    if wired {
                        HStack(spacing: 6) {
                            SpecValue("0xFF13", color: Theme.success)
                            Text("ready")
                                .font(Theme.captionFont)
                                .foregroundStyle(Theme.success)
                        }
                    } else {
                        Text("Unavailable")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.tertiary)
                    }
                }
                Hairline()

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: wired ? "checkmark.circle" : "info.circle")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(wired ? Theme.success : Theme.tertiary)
                    Text(connectionNote)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.panelInset)
            }
        }
    }

    private var connectionNote: String {
        switch model.connection.kind {
        case .wired: return "Wired configuration interface available."
        case .absent: return "No keyboard detected. Connect USB-C for full configuration."
        case .bluetooth, .dongle: return "Wireless links are input-only. Connect USB-C for full configuration."
        }
    }

    // MARK: - Onboard shortcuts

    private var shortcutsCard: some View {
        Card(padding: 0, fillHeight: true) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeaderBand("Onboard shortcuts", detail: "Handled by firmware on every connection.")

                ShortcutRow("USB-C mode", keys: ["4"])
                Hairline()
                ShortcutRow("2.4 GHz dongle", keys: ["~"])
                Hairline()
                ShortcutRow("Bluetooth slot", keys: ["1", "2", "3"])
                Hairline()
                SystemModeRow()
                Hairline()
                ShortcutRow("Light bar effect", keys: ["L-Shift"])
                Hairline()
                ShortcutRow("Side strip effect", keys: ["R-Shift"])
                Hairline()
                ShortcutRow("Light bar power", keys: ["B"])
                Hairline()

                Spacer(minLength: 0)

                Text("The light bar and side strips are firmware-only. AULA's Windows app cannot set them either.")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(Theme.panelInset)
            }
        }
    }
}

// MARK: - Form pieces

/// Small group heading at the top of a run of form rows.
fileprivate struct GroupLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.tertiary)
            .padding(.horizontal, Theme.panelInset)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A `FormRow` whose control is preceded by the key legend it governs, e.g. `Alt` + `Tab`.
fileprivate struct KeyedFormRow<Control: View>: View {
    let title: String
    let detail: String
    let keys: [String]
    @ViewBuilder var control: Control

    init(_ title: String, detail: String, keys: [String], @ViewBuilder control: () -> Control) {
        self.title = title
        self.detail = detail
        self.keys = keys
        self.control = control()
    }

    var body: some View {
        FormRow(title, detail: detail) {
            HStack(spacing: 12) {
                KeyCombo(keys)
                    .accessibilityHidden(true)
                control
            }
        }
    }
}

fileprivate struct SwitchControl: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(label, isOn: $isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(Theme.accent)
    }
}

/// Debounce level 1–5: a stepped slider with its current value at the trailing edge.
fileprivate struct ResponseControl: View {
    @Binding var value: UInt8

    var body: some View {
        HStack(spacing: 10) {
            Text("1")
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.tertiary)
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = UInt8($0.rounded()) }
                ),
                in: 1...5, step: 1
            )
            .controlSize(.small)
            .tint(Theme.accent)
            .frame(width: 150)
            .accessibilityLabel("Key response level")
            Text("5")
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.tertiary)
            ValueChip("Level \(value)")
        }
    }
}

/// Segmented sleep timer. Firmware codes: 0 never, 1 one minute, 2 five minutes, 3 thirty minutes.
fileprivate struct SleepSelector: View {
    @Binding var value: UInt8

    private let options: [(code: UInt8, label: String, help: String)] = [
        (0, "Never", "Never sleep"),
        (1, "1 min", "1 minute"),
        (2, "5 min", "5 minutes"),
        (3, "30 min", "30 minutes"),
    ]

    /// Unknown codes read as "Never", matching how the firmware value was labeled before.
    private var selected: UInt8 { (1...3).contains(value) ? value : 0 }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                if index > 0 {
                    Rectangle()
                        .fill(Theme.stroke)
                        .frame(width: 1, height: 14)
                        .opacity(selected == option.code || selected == options[index - 1].code ? 0 : 1)
                }
                SleepSegment(
                    label: option.label,
                    isSelected: selected == option.code
                ) {
                    value = option.code
                }
                .help(option.help)
                .accessibilityLabel("Sleep after \(option.help)")
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                .fill(Theme.field)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
        .fixedSize()
    }
}

fileprivate struct SleepSegment: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(isSelected ? Theme.text : (hovering ? Theme.text : Theme.secondary))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isSelected ? Theme.cardRaised : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(isSelected ? Theme.accent.opacity(0.85) : Color.clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Aside rows

/// Compact label/value line for the spec-sheet panels in the aside. Same height and insets as
/// `ShortcutRow`, so both aside panels share one rhythm.
fileprivate struct SpecRow<Value: View>: View {
    let label: String
    @ViewBuilder var value: Value

    init(_ label: String, @ViewBuilder value: () -> Value) {
        self.label = label
        self.value = value()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.secondary)
                .lineLimit(1)
            Spacer(minLength: 12)
            value
        }
        .frame(minHeight: asideRowHeight)
        .padding(.horizontal, Theme.panelInset)
    }
}

/// Height of one line in the aside's spec and shortcut lists.
fileprivate let asideRowHeight: CGFloat = 32

/// A read-only value. Monospaced only for machine values such as IDs and hex codes; names stay in
/// the regular face.
fileprivate struct SpecValue: View {
    let text: String
    var color: Color = Theme.text
    var machine: Bool = true

    init(_ text: String, color: Color = Theme.text, machine: Bool = true) {
        self.text = text
        self.color = color
        self.machine = machine
    }

    var body: some View {
        Text(text)
            .font(machine ? Theme.monoFont : .system(size: 12, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.middle)
            .textSelection(.enabled)
    }
}

/// One onboard shortcut: what it does on the left, `Fn` plus its key (or alternative keys) on the
/// right edge.
fileprivate struct ShortcutRow: View {
    let action: String
    let keys: [String]

    init(_ action: String, keys: [String]) {
        self.action = action
        self.keys = keys
    }

    var body: some View {
        SpecRow(action) {
            HStack(spacing: 3) {
                KeyTag("Fn")
                Text("+")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.tertiary)
                ForEach(Array(keys.enumerated()), id: \.offset) { index, key in
                    if index > 0 {
                        Text("/")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.tertiary)
                    }
                    KeyTag(key)
                }
            }
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Fn plus " + keys.joined(separator: " or "))
        }
    }
}

/// `Fn` + Q / W / E / R picks the host system. The shortcut line matches the other rows; a legend
/// underneath spells out which key selects which system, so the mapping reads directly.
fileprivate struct SystemModeRow: View {
    private let modes: [(key: String, name: String)] = [
        ("Q", "Android"), ("W", "Windows"), ("E", "macOS"), ("R", "iOS"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ShortcutRow("System mode", keys: modes.map(\.key))
            HStack(spacing: 0) {
                ForEach(Array(modes.enumerated()), id: \.offset) { index, mode in
                    if index > 0 { Spacer(minLength: 8) }
                    HStack(spacing: 5) {
                        Text(mode.key)
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.tertiary)
                        Text(mode.name)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.secondary)
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Fn plus \(mode.key): \(mode.name)")
                }
            }
            .padding(.horizontal, Theme.panelInset)
            .padding(.bottom, 10)
        }
    }
}
