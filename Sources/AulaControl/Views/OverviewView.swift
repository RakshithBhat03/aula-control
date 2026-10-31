import SwiftUI
import AulaKit

struct OverviewView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    eyebrow: "F108 Pro",
                    title: "Overview",
                    subtitle: "Connection, current lighting and remap state. Hardware settings are written over USB-C."
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
                            Label("Apply all", systemImage: "arrow.down.to.line")
                        }
                        .buttonStyle(AccentButtonStyle(enabled: model.canUseHardware || model.isPreview))
                        .disabled(model.isBusy)
                        .help("Send lighting, per-key colors, keymap, macros and options to the keyboard")
                    }
                }

                if model.connection.kind != .wired && !model.isPreview {
                    connectionBanner
                }

                devicePanel

                HStack(alignment: .top, spacing: 16) {
                    capabilityTable
                        .frame(maxWidth: .infinity)
                    VStack(spacing: 16) {
                        shortcutsPanel
                        setupPanel
                    }
                    .frame(width: 300)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Connection notice

    private var bannerTitle: String {
        switch model.connection.kind {
        case .absent: return "Keyboard not detected"
        case .dongle: return "Connected over 2.4 GHz"
        default: return "Connected over Bluetooth"
        }
    }

    private var bannerDetail: String {
        model.connection.kind == .absent
            ? "Connect USB-C and switch the keyboard to wired mode, or pair it over Bluetooth in macOS."
            : "Typing and macOS remapping work. Lighting, per-key RGB and onboard settings need USB-C."
    }

    private var connectionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: model.connection.kind.symbol)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Theme.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(bannerTitle)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(bannerDetail)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                Text("Wired mode")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.tertiary)
                KeyCombo(["Fn", "4"])
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Press Fn plus 4 for wired mode")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .fill(Theme.field)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(Theme.strokeStrong, lineWidth: 1)
        )
    }

    // MARK: - Device panel

    private var devicePanel: some View {
        Card(padding: 0) {
            VStack(spacing: 0) {
                PanelHeader(
                    model.connection.product.isEmpty ? "AULA F108 Pro" : model.connection.product,
                    detail: "Backlight preview and live readouts"
                ) {
                    HStack(spacing: 8) {
                        Button {
                            model.section = .lighting
                        } label: {
                            Label("Lighting", systemImage: "light.max")
                        }
                        .buttonStyle(GhostButtonStyle())

                        Button {
                            model.section = .perKey
                        } label: {
                            Label("Per-key RGB", systemImage: "paintpalette")
                        }
                        .buttonStyle(GhostButtonStyle())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

                hairline

                KeyboardView(
                    colorFor: { key in
                        let hue = 0.06 + (key.x / 22.5) * 0.58
                        return AulaRGB.hue(hue, saturation: 0.78, value: 1)
                    },
                    isInteractive: false
                )
                .padding(.horizontal, 22)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity)

                hairline

                readoutStrip
            }
        }
    }

    private var hairline: some View {
        Rectangle().fill(Theme.stroke).frame(height: 1)
    }

    private var readoutStrip: some View {
        HStack(alignment: .top, spacing: 0) {
            connectionReadout
            columnDivider
            effectReadout
            columnDivider
            brightnessReadout
            columnDivider
            onboardReadout
            columnDivider
            macRemapReadout
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var columnDivider: some View {
        Rectangle().fill(Theme.stroke).frame(width: 1)
    }

    private var usbIdentifier: String {
        guard model.connection.vendorID != 0 else { return "—" }
        return String(format: "%04X:%04X", model.connection.vendorID, model.connection.productID)
    }

    private var connectionReadout: some View {
        ReadoutColumn(label: "Connection") {
            HStack(spacing: 7) {
                Circle()
                    .fill(model.connectionColor)
                    .frame(width: 6, height: 6)
                Text(model.hardwareStatusText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
            }
        } footer: {
            HStack(spacing: 6) {
                Text("VID:PID")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.tertiary)
                ValueChip(usbIdentifier, color: Theme.secondary)
            }
        }
    }

    private var effectReadout: some View {
        ReadoutColumn(label: "Effect") {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color(model.state.lighting.color))
                    .frame(width: 11, height: 11)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(Theme.strokeStrong, lineWidth: 1)
                    )
                Text(model.state.lighting.mode.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        } footer: {
            HStack(spacing: 8) {
                ValueChip("#\(model.state.lighting.color.hex)", color: Theme.secondary)
                Menu {
                    ForEach(LightingMode.allCases) { mode in
                        Button(mode.name) { model.setLightingMode(mode) }
                    }
                } label: {
                    Text("Change")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Choose a backlight effect")
            }
        }
    }

    private var brightnessReadout: some View {
        ReadoutColumn(label: "Brightness") {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(model.state.lighting.brightness)")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.text)
                Text("/ 5")
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.tertiary)
            }
            .monospacedDigit()
        } footer: {
            HStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { Double(model.state.lighting.brightness) },
                        set: { model.state.lighting.brightness = UInt8($0) }
                    ),
                    in: 0...5, step: 1
                )
                .controlSize(.small)
                .tint(Theme.accent)
                .accessibilityLabel("Brightness")

                Button("Send") {
                    model.applyLighting()
                }
                .buttonStyle(GhostButtonStyle())
                .disabled(!model.canUseHardware && !model.isPreview)
                .opacity(model.canUseHardware || model.isPreview ? 1 : 0.4)
                .help("Send lighting to the keyboard")
            }
        }
    }

    private var onboardReadout: some View {
        ReadoutColumn(label: "Onboard remaps") {
            Text("\(model.state.keymap.count + model.state.fnKeymap.count)")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(Theme.text)
        } footer: {
            HStack(spacing: 8) {
                Text("\(model.state.keymap.count) base · \(model.state.fnKeymap.count) Fn")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Button("Edit") { model.section = .keymap }
                    .buttonStyle(GhostButtonStyle())
                    .help("Open Keymap")
            }
        }
    }

    private var macRemapReadout: some View {
        ReadoutColumn(label: "Mac remap") {
            HStack(spacing: 7) {
                Circle()
                    .fill(model.remapRunning ? Theme.success : Theme.tertiary)
                    .frame(width: 6, height: 6)
                Text(model.remapRunning ? "Active" : "Inactive")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.text)
            }
        } footer: {
            HStack(spacing: 8) {
                Toggle("Mac remap", isOn: Binding(
                    get: { model.state.macRemap.enabled },
                    set: { model.setMacRemapEnabled($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(Theme.accent)

                Spacer(minLength: 0)

                Button("Configure") { model.section = .macRemap }
                    .buttonStyle(GhostButtonStyle())
            }
        }
    }

    // MARK: - Capabilities

    private struct Capability: Identifiable {
        let name: String
        let wired: Bool
        let bluetooth: Bool
        var id: String { name }
    }

    private let capabilities: [Capability] = [
        Capability(name: "Backlight effects and color", wired: true, bluetooth: false),
        Capability(name: "Per-key RGB", wired: true, bluetooth: false),
        Capability(name: "Onboard remap, base and Fn layers", wired: true, bluetooth: false),
        Capability(name: "Macros stored on the keyboard", wired: true, bluetooth: false),
        Capability(name: "Sleep, debounce and key locks", wired: true, bluetooth: false),
        Capability(name: "LCD clock sync", wired: true, bluetooth: false),
        Capability(name: "Typing and media keys", wired: true, bluetooth: true),
        Capability(name: "Per-key macOS remap", wired: true, bluetooth: true),
        Capability(name: "Macro playback on this Mac", wired: true, bluetooth: true),
    ]

    private let transportColumnWidth: CGFloat = 96

    private var capabilityTable: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeader("What works where", detail: "Hardware settings use the wired config interface.") {
                    StatusPill(
                        text: model.connection.kind.supportsHardwareConfig ? "USB ready" : "USB needed",
                        color: model.connection.kind.supportsHardwareConfig ? Theme.success : Theme.tertiary,
                        icon: model.connection.kind.supportsHardwareConfig ? "checkmark" : "cable.connector"
                    )
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 12)

                hairline

                HStack(spacing: 0) {
                    Text("Capability")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    transportHeader("USB-C", isCurrent: model.connection.kind == .wired)
                    transportHeader("Bluetooth", isCurrent: model.connection.kind == .bluetooth)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.tertiary)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Theme.field)

                hairline

                ForEach(Array(capabilities.enumerated()), id: \.element.id) { index, capability in
                    if index > 0 {
                        Rectangle().fill(Theme.stroke).frame(height: 1).padding(.leading, 18)
                    }
                    HStack(spacing: 0) {
                        Text(capability.name)
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        supportMark(capability.wired)
                        supportMark(capability.bluetooth)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "\(capability.name): USB-C \(capability.wired ? "yes" : "no"), Bluetooth \(capability.bluetooth ? "yes" : "no")"
                    )
                }

                hairline

                Text("Bluetooth does not expose the config interface; this is an AULA firmware limitation. Secure Input fields bypass macOS remapping on any transport.")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
            }
        }
    }

    private func transportHeader(_ title: String, isCurrent: Bool) -> some View {
        HStack(spacing: 5) {
            if isCurrent {
                Circle().fill(Theme.success).frame(width: 5, height: 5)
            }
            Text(title)
                .foregroundStyle(isCurrent ? Theme.text : Theme.tertiary)
        }
        .frame(width: transportColumnWidth)
        .help(isCurrent ? "Current connection" : "")
    }

    private func supportMark(_ supported: Bool) -> some View {
        Group {
            if supported {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.text.opacity(0.85))
            } else {
                Text("—")
                    .font(Theme.monoFont)
                    .foregroundStyle(Theme.tertiary)
            }
        }
        .frame(width: transportColumnWidth)
    }

    // MARK: - Side panels

    private var shortcutsPanel: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeader("Hardware shortcuts", detail: "Handled by the firmware, no app needed.")
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 10)
                hairline
                VStack(spacing: 0) {
                    shortcutRow(["Fn", "4"], "USB-C wired")
                    shortcutRow(["Fn", "1–3"], "Bluetooth slot 1–3")
                    shortcutRow(["Fn", "E"], "macOS device mode")
                    shortcutRow(["Fn", "L-Shift"], "Light bar effect")
                    shortcutRow(["Fn", "R-Shift"], "Side strip effect")
                    shortcutRow(["Fn", "/"], "Side strip color", isLast: true)
                }
            }
        }
    }

    private func shortcutRow(_ keys: [String], _ action: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                KeyCombo(keys)
                Spacer(minLength: 8)
                Text(action)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            if !isLast {
                Rectangle().fill(Theme.stroke).frame(height: 1).padding(.leading, 16)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var setupPanel: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeader("Setup")
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 10)
                hairline
                stepRow(
                    number: 1,
                    title: "Connect over USB-C",
                    detail: "Settings are sent over the wired config interface.",
                    done: model.connection.kind == .wired
                )
                Rectangle().fill(Theme.stroke).frame(height: 1).padding(.leading, 16)
                stepRow(
                    number: 2,
                    title: "Set lighting",
                    detail: "Pick an effect or paint individual keys.",
                    done: !model.state.perKey.isEmpty || model.state.lighting.mode != .rolling
                )
                Rectangle().fill(Theme.stroke).frame(height: 1).padding(.leading, 16)
                stepRow(
                    number: 3,
                    title: "Enable Mac remap",
                    detail: "Per-device remapping, configured in Mac remap.",
                    done: model.state.macRemap.enabled
                )
                hairline
                Text("Settings are saved locally and can be re-applied at any time.")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
        }
    }

    private func stepRow(number: Int, title: String, detail: String, done: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Group {
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Theme.success)
                } else {
                    Text("\(number)")
                        .font(Theme.monoFont)
                        .foregroundStyle(Theme.tertiary)
                }
            }
            .frame(width: 14, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(done ? Theme.secondary : Theme.text)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? "Done" : "Not done")
    }
}

/// One cell of the readout strip: a caption, the live value, and a control row pinned to the bottom
/// so controls line up across columns of differing content.
fileprivate struct ReadoutColumn<Value: View, Footer: View>: View {
    let label: String
    @ViewBuilder var value: Value
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.tertiary)
            value
            Spacer(minLength: 8)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
