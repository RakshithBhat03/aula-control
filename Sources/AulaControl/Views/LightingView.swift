import SwiftUI
import AulaKit

struct LightingView: View {
    @EnvironmentObject var model: AppModel

    private var lighting: LightingConfig { model.state.lighting }

    private var canSend: Bool { model.canUseHardware || model.isPreview }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(model.state.lighting.color) },
            set: { model.state.lighting.color = AulaRGB($0) }
        )
    }

    private var colorLocked: Bool { !lighting.mode.supportsColor || lighting.colorful }
    private var colorfulLocked: Bool { !lighting.mode.supportsColor || lighting.mode.forcesRainbow }

    private var colorSourceText: String {
        if lighting.mode == .off { return "LEDs off" }
        if lighting.mode.forcesRainbow { return "Built-in rainbow" }
        return lighting.colorful ? "Colorful" : "Single color"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    eyebrow: "USB-C",
                    title: "Lighting",
                    subtitle: "20 firmware effects with color, brightness, speed and direction. Stored on the keyboard, so settings follow it between machines."
                ) {
                    StatusPill(
                        text: canSend ? "Ready to send" : "USB-C required",
                        color: canSend ? Theme.success : Theme.secondary,
                        icon: canSend ? nil : "cable.connector"
                    )
                }

                boardPreview

                HStack(alignment: .top, spacing: 16) {
                    effectsPanel
                    inspector
                        .frame(width: 320)
                }

                firmwareZones
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Preview

    private var boardPreview: some View {
        Card(padding: 0) {
            VStack(spacing: 0) {
                KeyboardView(colorFor: previewColor, isInteractive: false)
                    .padding(14)
                    .accessibilityLabel("Lighting preview")
                Rectangle().fill(Theme.stroke).frame(height: 1)
                HStack(spacing: 0) {
                    ReadoutCell(label: "Effect", value: lighting.mode.name, mono: false)
                    ReadoutDivider()
                    ReadoutCell(label: "Mode", value: String(format: "0x%02X", lighting.mode.rawValue))
                    ReadoutDivider()
                    ReadoutCell(
                        label: "Color",
                        value: lighting.mode == .off || colorLocked ? colorSourceText : "#\(lighting.color.hex)",
                        mono: !(lighting.mode == .off || colorLocked)
                    )
                    ReadoutDivider()
                    ReadoutCell(label: "Brightness", value: "\(lighting.brightness)/5")
                    ReadoutDivider()
                    ReadoutCell(label: "Speed", value: lighting.mode.supportsSpeed ? "\(lighting.speed)/5" : "–")
                    ReadoutDivider()
                    ReadoutCell(
                        label: "Direction",
                        value: lighting.mode.supportsDirection ? (lighting.direction == 0 ? "Forward" : "Reverse") : "–",
                        mono: false
                    )
                }
                .frame(height: 48)
            }
        }
    }

    /// Static approximation of the effect: the board shows the colors and brightness the keyboard
    /// will use, not the animation itself.
    private func previewColor(_ key: KeyCap) -> AulaRGB? {
        guard lighting.mode != .off else { return nil }
        let level = Double(lighting.brightness) / 5
        guard level > 0 else { return nil }
        if lighting.mode.forcesRainbow || lighting.colorful {
            let span = KeyLayout.f108Pro.widthUnits
            return AulaRGB.hue((key.x + key.width / 2) / span, saturation: 0.8, value: 0.35 + 0.65 * level)
        }
        let c = lighting.color
        let scale = 0.35 + 0.65 * level
        return AulaRGB(
            UInt8(Double(c.r) * scale),
            UInt8(Double(c.g) * scale),
            UInt8(Double(c.b) * scale)
        )
    }

    // MARK: Effects

    private var effectsPanel: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader("Effect") {
                    Text("\(LightingMode.allCases.count) modes")
                        .font(Theme.monoFont)
                        .foregroundStyle(Theme.tertiary)
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 124), spacing: 6)],
                    spacing: 6
                ) {
                    ForEach(LightingMode.allCases) { mode in
                        effectTile(mode)
                    }
                }
            }
        }
    }

    private func effectTile(_ mode: LightingMode) -> some View {
        let selected = lighting.mode == mode
        return SelectableTile(isSelected: selected) {
            model.setLightingMode(mode)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(selected ? Theme.text : Theme.secondary)
                    .frame(width: 16)
                Text(mode.name)
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Theme.text : Theme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 4)
                Text(String(format: "%02d", mode.rawValue))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(selected ? Theme.accent : Theme.tertiary)
            }
        }
        .accessibilityLabel(mode.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Inspector

    private var inspector: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeader(lighting.mode.name, detail: colorSourceText) {
                    Image(systemName: lighting.mode.symbol)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Theme.tertiary)
                }
                .padding(.bottom, 14)

                hairline

                HStack(spacing: 8) {
                    Text("Color")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                    Spacer()
                    ValueChip("#\(lighting.color.hex)", color: colorLocked ? Theme.tertiary : Theme.text)
                    ColorPicker("", selection: colorBinding, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 30)
                        .disabled(colorLocked)
                        .opacity(colorLocked ? 0.35 : 1)
                        .accessibilityLabel("Effect color")
                }
                .padding(.vertical, 12)

                hairline

                ToggleRow(
                    title: "Colorful",
                    subtitle: "Rainbow instead of a single color",
                    isOn: Binding(
                        get: { model.state.lighting.colorful },
                        set: { model.state.lighting.colorful = $0 }
                    )
                )
                .disabled(colorfulLocked)
                .opacity(colorfulLocked ? 0.4 : 1)
                .padding(.vertical, 12)

                hairline

                SliderRow(
                    title: "Brightness",
                    value: Binding(
                        get: { Double(model.state.lighting.brightness) },
                        set: { model.state.lighting.brightness = UInt8($0) }
                    ),
                    range: 0...5, step: 1,
                    valueLabel: "\(lighting.brightness)"
                )
                .padding(.vertical, 12)

                if lighting.mode.supportsSpeed {
                    hairline
                    SliderRow(
                        title: "Speed",
                        value: Binding(
                            get: { Double(model.state.lighting.speed) },
                            set: { model.state.lighting.speed = UInt8($0) }
                        ),
                        range: 0...5, step: 1,
                        valueLabel: "\(lighting.speed)"
                    )
                    .padding(.vertical, 12)
                }

                if lighting.mode.supportsDirection {
                    hairline
                    HStack(spacing: 12) {
                        Text("Direction")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.secondary)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { model.state.lighting.direction },
                            set: { model.state.lighting.direction = $0 }
                        )) {
                            Text("Forward").tag(UInt8(0))
                            Text("Reverse").tag(UInt8(1))
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .controlSize(.small)
                        .frame(width: 160)
                        .accessibilityLabel("Direction")
                    }
                    .padding(.vertical, 12)
                }

                hairline

                HStack(spacing: 8) {
                    Button {
                        model.applyLighting()
                    } label: {
                        Label("Apply lighting", systemImage: "arrow.down.to.line")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AccentButtonStyle(enabled: canSend))
                    .disabled(model.isBusy || !canSend)

                    Button {
                        model.state.lighting = .default
                        model.setLightingMode(.rolling)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(GhostButtonStyle())
                    .help("Reset to defaults")
                    .accessibilityLabel("Reset to defaults")
                }
                .padding(.top, 14)

                if !canSend {
                    Label("Connect USB-C to apply", systemImage: "cable.connector")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, 10)
                }
            }
        }
    }

    private var hairline: some View {
        Rectangle().fill(Theme.stroke).frame(height: 1)
    }

    // MARK: Firmware-only zones

    private var firmwareZones: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader(
                    "Light bar and side strips",
                    detail: "Driven by a separate controller that neither this app nor the vendor app can write. Use the firmware shortcuts."
                )

                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        tableHeading("Function")
                        tableHeading("Light bar")
                        tableHeading("Side strip")
                    }
                    shortcutRow("Effect", lightBar: ["Fn", "L-Shift"], sideStrip: ["Fn", "R-Shift"])
                    shortcutRow("Brightness", lightBar: ["Fn", "L-Alt"], sideStrip: ["Fn", "R-Alt"])
                    shortcutRow("Speed", lightBar: ["Fn", "L-Ctrl"], sideStrip: nil)
                    shortcutRow("Color", lightBar: nil, sideStrip: ["Fn", "/"])
                }
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
            }
        }
    }

    private func tableHeading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Theme.field)
    }

    @ViewBuilder
    private func shortcutRow(_ function: String, lightBar: [String]?, sideStrip: [String]?) -> some View {
        Rectangle().fill(Theme.stroke).frame(height: 1).gridCellUnsizedAxes(.horizontal)
        GridRow {
            Text(function)
                .font(.system(size: 12))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                .padding(.horizontal, 12)
            comboCell(lightBar)
            comboCell(sideStrip)
        }
    }

    @ViewBuilder
    private func comboCell(_ keys: [String]?) -> some View {
        Group {
            if let keys {
                KeyCombo(keys)
            } else {
                Text("–")
                    .font(Theme.monoFont)
                    .foregroundStyle(Theme.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

/// One column of the readout strip under the board: small label above a value.
private struct ReadoutCell: View {
    let label: String
    let value: String
    var mono: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Theme.tertiary)
            Text(value)
                .font(mono ? Theme.monoFont : .system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
    }
}

private struct ReadoutDivider: View {
    var body: some View {
        Rectangle().fill(Theme.stroke).frame(width: 1)
    }
}
