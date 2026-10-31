import SwiftUI
import AulaKit

struct DeviceView: View {
    @EnvironmentObject var model: AppModel
    @State private var showResetConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    eyebrow: "KEYBOARD",
                    title: "Device",
                    subtitle: "Connection details, power behavior and the firmware settings that are easy to forget."
                ) {
                    HStack(spacing: 10) {
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
                        .buttonStyle(AccentButtonStyle(enabled: model.canUseHardware || model.isPreview))
                        .disabled(model.isBusy || !(model.canUseHardware || model.isPreview))
                    }
                }

                if model.connection.kind != .wired && !model.isPreview {
                    HStack(spacing: 12) {
                        Image(systemName: "cable.connector")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                        Text("Options on this page write to the keyboard and need the USB-C connection. Press Fn + 4 to switch modes.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.accent.opacity(0.9))
                        Spacer()
                    }
                    .padding(13)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.accent.opacity(0.18), lineWidth: 1))
                }

                HStack(alignment: .top, spacing: 18) {
                    connectionCard
                        .frame(maxWidth: .infinity)
                    optionsCard
                        .frame(maxWidth: .infinity)
                }

                HStack(alignment: .top, spacing: 18) {
                    utilitiesCard
                        .frame(maxWidth: .infinity)
                    firmwareCard
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .padding(.bottom, 34)
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

    private var connectionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Connection")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Circle()
                        .fill(model.connectionColor)
                        .frame(width: 7, height: 7)
                        .shadow(color: model.connectionColor.opacity(0.8), radius: 5)
                }

                VStack(spacing: 0) {
                    detailRow("Product", model.connection.kind == .absent ? "—" : model.connection.product)
                    divider
                    detailRow("Transport", model.connection.kind == .absent ? "—" : model.connection.transport)
                    divider
                    detailRow("USB ID", String(format: "%04X:%04X", model.connection.vendorID, model.connection.productID))
                    divider
                    detailRow("Unique ID", model.connection.uniqueID ?? "—", mono: true)
                    divider
                    detailRow("HID services", "\(AulaDiscovery.allAulaDevices().count)")
                    divider
                    detailRow("Config interface", model.connection.kind == .wired ? "0xFF13 ready" : "unavailable")
                }

                HStack(spacing: 9) {
                    Image(systemName: model.connection.kind == .wired ? "checkmark.circle.fill" : "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(model.connection.kind == .wired ? Theme.success : Theme.accent)
                    Text(model.connection.kind == .wired
                         ? "The wired configuration interface is available."
                         : "Bluetooth is input-only. Plug in USB-C for full config.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.secondary)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.025)))
            }
        }
    }

    private func detailRow(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: mono ? 9.5 : 11, weight: .medium, design: mono ? .monospaced : .default))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .padding(.vertical, 8)
    }

    private var divider: some View {
        Rectangle().fill(Theme.stroke).frame(height: 1)
    }

    private var sleepLabel: String {
        switch model.state.options.sleep {
        case 1: return "1 min"
        case 2: return "5 min"
        case 3: return "30 min"
        default: return "Never"
        }
    }

    private var optionsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Power & response")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Text("FIRMWARE")
                        .font(.system(size: 8.5, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.tertiary)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Sleep after inactivity")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text)
                        Text("Turn the radio off when idle")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.secondary)
                    }
                    Spacer()
                    Menu {
                        Button("Never") { model.state.options.sleep = 0 }
                        Button("1 minute") { model.state.options.sleep = 1 }
                        Button("5 minutes") { model.state.options.sleep = 2 }
                        Button("30 minutes") { model.state.options.sleep = 3 }
                    } label: {
                        HStack(spacing: 6) {
                            Text(sleepLabel)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(Theme.text)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Theme.tertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Theme.field))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.stroke, lineWidth: 1))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                SliderRow(
                    title: "Key response / debounce",
                    value: Binding(
                        get: { Double(model.state.options.response) },
                        set: { model.state.options.response = UInt8($0) }
                    ),
                    range: 1...5, step: 1,
                    valueLabel: "Level \(model.state.options.response)"
                )

                ToggleRow(
                    title: "FN tap toggle",
                    subtitle: "Tap FN to lock it instead of holding",
                    isOn: Binding(
                        get: { model.state.options.fnToggle == 1 },
                        set: { model.state.options.fnToggle = $0 ? 1 : 0 }
                    )
                )

                Rectangle().fill(Theme.stroke).frame(height: 1)

                Text("Key locks")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.secondary)

                ToggleRow(
                    title: "Lock Windows key",
                    subtitle: "Prevent accidental Start-menu presses",
                    isOn: Binding(
                        get: { model.state.options.lockWin },
                        set: { model.state.options.lockWin = $0 }
                    )
                )
                ToggleRow(
                    title: "Lock Alt + Tab",
                    subtitle: "Disable the task switcher chord",
                    isOn: Binding(
                        get: { model.state.options.lockAltTab },
                        set: { model.state.options.lockAltTab = $0 }
                    )
                )
                ToggleRow(
                    title: "Lock Alt + F4",
                    subtitle: "Disable the close-window chord",
                    isOn: Binding(
                        get: { model.state.options.lockAltF4 },
                        set: { model.state.options.lockAltF4 = $0 }
                    )
                )

                Button {
                    model.applyOptions()
                } label: {
                    Label("Apply device options", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccentButtonStyle(enabled: model.canUseHardware || model.isPreview))
                .disabled(model.isBusy || !(model.canUseHardware || model.isPreview))
            }
        }
    }

    private var utilitiesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Utilities")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)

                utilityRow(
                    icon: "clock",
                    title: "Sync LCD clock",
                    detail: "Send the current date and time to the 240 × 135 screen.",
                    action: "Sync now"
                ) {
                    model.syncClock()
                }

                Rectangle().fill(Theme.stroke).frame(height: 1)

                utilityRow(
                    icon: "arrow.counterclockwise",
                    title: "Reset onboard keymap",
                    detail: "Clear the \(model.selectedLayer.title.lowercased()) and restore factory behavior.",
                    action: "Reset…",
                    danger: true
                ) {
                    showResetConfirm = true
                }

                Rectangle().fill(Theme.stroke).frame(height: 1)

                utilityRow(
                    icon: "square.and.arrow.down",
                    title: "Apply saved configuration",
                    detail: "Re-send lighting, keymap, macros, per-key colors and options.",
                    action: "Push all"
                ) {
                    model.pushAll()
                }
            }
        }
    }

    private func utilityRow(
        icon: String, title: String, detail: String, action: String,
        danger: Bool = false, perform: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(danger ? Theme.danger : Theme.accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text)
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.secondary)
                    .lineSpacing(1.5)
            }
            Spacer()
            Button(action: perform) {
                Text(action)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(danger ? Theme.danger : Theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(model.isBusy || (!(model.canUseHardware || model.isPreview) && !danger))
            .opacity(model.isBusy || (!(model.canUseHardware || model.isPreview) && !danger) ? 0.35 : 1)
        }
    }

    private var firmwareCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text("Firmware cheat sheet")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Image(systemName: "keyboard")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.tertiary)
                }

                shortcutRow("Fn + 4", "USB-C mode")
                shortcutRow("Fn + ~", "2.4 GHz dongle")
                shortcutRow("Fn + 1 / 2 / 3", "Bluetooth slot")
                shortcutRow("Fn + Q / W / E / R", "Android / Windows / Mac / iOS")
                shortcutRow("Fn + L-Shift", "Light bar effect")
                shortcutRow("Fn + R-Shift", "Side strip effect")
                shortcutRow("Fn + B", "Light bar power")

                Text("The light bar and side strips are controlled by firmware only. AULA's own Windows app cannot change them either.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.tertiary)
                    .lineSpacing(1.5)
                    .padding(.top, 2)
            }
        }
    }

    private func shortcutRow(_ keys: String, _ action: String) -> some View {
        HStack {
            Text(keys)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.06)))
            Spacer()
            Text(action)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.secondary)
        }
    }
}
