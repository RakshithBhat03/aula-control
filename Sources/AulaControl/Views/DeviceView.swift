import SwiftUI
import AulaKit

struct DeviceView: View {
    @EnvironmentObject var model: AppModel
    @State private var showResetConfirm = false

    private var hardwareReady: Bool { model.canUseHardware || model.isPreview }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    eyebrow: "USB-C",
                    title: "Device",
                    subtitle: "Connection details, power and response options, and key locks stored in the keyboard's firmware."
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
                            Label("Push saved config", systemImage: "arrow.down.to.line")
                        }
                        .buttonStyle(GhostButtonStyle())
                        .disabled(model.isBusy || !hardwareReady)
                    }
                }

                if model.connection.kind != .wired && !model.isPreview {
                    transportNotice
                }

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        optionsCard
                        utilitiesCard
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 16) {
                        connectionCard
                        firmwareCard
                    }
                    .frame(width: 344)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                .fill(Theme.field)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    // MARK: - Options

    private var optionsCard: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeader(
                    "Firmware options",
                    detail: "Saved with your config. Apply writes them to the keyboard."
                )
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)

                GroupLabel("Power and response")

                DeviceFormRow(title: "Sleep after inactivity", detail: "Turns the radio off when idle") {
                    SleepSelector(value: Binding(
                        get: { model.state.options.sleep },
                        set: { model.state.options.sleep = $0 }
                    ))
                }
                Hairline().padding(.leading, 18)
                VStack(alignment: .leading, spacing: 3) {
                    SliderRow(
                        title: "Key response / debounce",
                        value: Binding(
                            get: { Double(model.state.options.response) },
                            set: { model.state.options.response = UInt8($0) }
                        ),
                        range: 1...5, step: 1,
                        valueLabel: "Level \(model.state.options.response)"
                    )
                    HStack {
                        Text("1").font(.system(size: 10, design: .monospaced))
                        Spacer()
                        Text("5").font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundStyle(Theme.tertiary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                Hairline().padding(.leading, 18)
                DeviceFormRow(title: "Fn tap toggle", detail: "Tap to latch the layer instead of holding", keys: ["Fn"]) {
                    SwitchControl(
                        label: "Fn tap toggle",
                        isOn: Binding(
                            get: { model.state.options.fnToggle == 1 },
                            set: { model.state.options.fnToggle = $0 ? 1 : 0 }
                        )
                    )
                }

                GroupLabel("Key locks")

                DeviceFormRow(title: "Lock Windows key", detail: "Prevents accidental Start menu presses", keys: ["Win"]) {
                    SwitchControl(
                        label: "Lock Windows key",
                        isOn: Binding(
                            get: { model.state.options.lockWin },
                            set: { model.state.options.lockWin = $0 }
                        )
                    )
                }
                Hairline().padding(.leading, 18)
                DeviceFormRow(title: "Lock Alt + Tab", detail: "Disables the task switcher chord", keys: ["Alt", "Tab"]) {
                    SwitchControl(
                        label: "Lock Alt + Tab",
                        isOn: Binding(
                            get: { model.state.options.lockAltTab },
                            set: { model.state.options.lockAltTab = $0 }
                        )
                    )
                }
                Hairline().padding(.leading, 18)
                DeviceFormRow(title: "Lock Alt + F4", detail: "Disables the close window chord", keys: ["Alt", "F4"]) {
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
                    Spacer()
                    Button {
                        model.applyOptions()
                    } label: {
                        Label("Apply device options", systemImage: "checkmark")
                    }
                    .buttonStyle(AccentButtonStyle(enabled: hardwareReady))
                    .disabled(model.isBusy || !hardwareReady)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Utilities

    private var utilitiesCard: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeader("Utilities")
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 6)

                utilityRow(
                    title: "Sync LCD clock",
                    detail: "Sends the current date and time to the 240 × 135 screen.",
                    action: "Sync now"
                ) {
                    model.syncClock()
                }
                Hairline().padding(.leading, 18)
                utilityRow(
                    title: "Reset onboard keymap",
                    detail: "Clears the \(model.selectedLayer.title.lowercased()) and restores factory behavior.",
                    action: "Reset…",
                    danger: true
                ) {
                    showResetConfirm = true
                }
                Hairline().padding(.leading, 18)
                utilityRow(
                    title: "Apply saved configuration",
                    detail: "Re-sends lighting, keymap, macros, per-key colors and options.",
                    action: "Push all"
                ) {
                    model.pushAll()
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func utilityRow(
        title: String, detail: String, action: String,
        danger: Bool = false, perform: @escaping () -> Void
    ) -> some View {
        let disabled = model.isBusy || (!hardwareReady && !danger)
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.text)
                Text(detail)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button(action: perform) {
                Text(action)
            }
            .buttonStyle(GhostButtonStyle(danger: danger))
            .disabled(disabled)
            .opacity(disabled ? 0.4 : 1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }

    // MARK: - Connection

    private var connectionCard: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeader("Connection") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(model.connectionColor)
                            .frame(width: 6, height: 6)
                        Text(model.connection.kind.title)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

                Hairline()
                specRow("Product", model.connection.kind == .absent ? "—" : model.connection.product)
                Hairline()
                specRow("Transport", model.connection.kind == .absent ? "—" : model.connection.transport)
                Hairline()
                specRow("USB ID", String(format: "%04X:%04X", model.connection.vendorID, model.connection.productID))
                Hairline()
                specRow("Unique ID", model.connection.uniqueID ?? "—")
                Hairline()
                specRow("HID services", "\(AulaDiscovery.allAulaDevices().count)")
                Hairline()
                specRow(
                    "Config interface",
                    model.connection.kind == .wired ? "0xFF13 ready" : "unavailable",
                    color: model.connection.kind == .wired ? Theme.success : Theme.tertiary
                )
                Hairline()

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: model.connection.kind == .wired ? "checkmark.circle" : "info.circle")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(model.connection.kind == .wired ? Theme.success : Theme.tertiary)
                        .padding(.top, 1)
                    Text(connectionNote)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
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

    private func specRow(_ label: String, _ value: String, color: Color = Theme.text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(Theme.monoFont)
                .monospacedDigit()
                .foregroundStyle(color)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Firmware shortcuts

    private var firmwareCard: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeader("Onboard shortcuts", detail: "Handled by firmware on every connection.")
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                Hairline()
                shortcutRow(["4"], "USB-C mode")
                Hairline()
                shortcutRow(["~"], "2.4 GHz dongle")
                Hairline()
                shortcutRow(["1", "2", "3"], "Bluetooth slot")
                Hairline()
                shortcutRow(["Q", "W", "E", "R"], "Android / Win / Mac / iOS")
                Hairline()
                shortcutRow(["L-Shift"], "Light bar effect")
                Hairline()
                shortcutRow(["R-Shift"], "Side strip effect")
                Hairline()
                shortcutRow(["B"], "Light bar power")
                Hairline()

                Text("The light bar and side strips are firmware-only. AULA's Windows app cannot set them either.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
    }

    /// Every onboard shortcut is Fn plus one of several alternative keys.
    private func shortcutRow(_ alternatives: [String], _ action: String) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 3) {
                KeyTag("Fn")
                Text("+")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.tertiary)
                ForEach(Array(alternatives.enumerated()), id: \.offset) { index, key in
                    if index > 0 {
                        Text("/")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.tertiary)
                    }
                    KeyTag(key)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Fn plus " + alternatives.joined(separator: " or "))
            Spacer(minLength: 8)
            Text(action)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
    }
}

// MARK: - Form pieces

/// Small group heading between hairline-separated form rows.
fileprivate struct GroupLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Theme.stroke).frame(height: 1)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.tertiary)
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 2)
        }
    }
}

/// A settings row: title and detail on the left, optional key legend, control on the right.
fileprivate struct DeviceFormRow<Control: View>: View {
    let title: String
    let detail: String
    var keys: [String] = []
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.text)
                Text(detail)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            if !keys.isEmpty {
                KeyCombo(keys)
                    .accessibilityHidden(true)
            }
            control
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
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
            .padding(.leading, 6)
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
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(isSelected ? Theme.text : (hovering ? Theme.text : Theme.secondary))
                .padding(.horizontal, 9)
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
