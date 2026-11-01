import SwiftUI
import AulaKit

struct LightingView: View {
    @EnvironmentObject var model: AppModel

    private var lighting: LightingConfig { model.state.lighting }

    private var canSend: Bool { model.canUseHardware || model.isPreview }

    /// Width of the right-hand control column in the inspector, so sliders and the segmented
    /// picker share one leading and one trailing edge.
    private let controlWidth: CGFloat = 156

    /// Five pads across, four down: the 20 firmware modes in one block.
    private let padColumns = 5

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

    /// Why the color well is disabled, shown under the row title.
    private var colorLockReason: String? {
        guard colorLocked else { return nil }
        if lighting.mode == .off { return "LEDs off" }
        if lighting.mode.forcesRainbow { return "Built-in rainbow" }
        return "Colorful is on"
    }

    var body: some View {
        PageScroll {
            PageHeader(
                eyebrow: "USB-C",
                title: "Lighting",
                subtitle: "20 firmware effects with color, brightness, speed and direction. Stored on the keyboard, so settings follow it between machines."
            ) {
                HStack(spacing: 10) {
                    StatusPill(
                        text: canSend ? "Ready to send" : "USB-C required",
                        color: canSend ? Theme.success : Theme.secondary,
                        icon: canSend ? nil : "cable.connector"
                    )
                    Button {
                        model.applyLighting()
                    } label: {
                        Label("Apply lighting", systemImage: "arrow.down.to.line")
                    }
                    .buttonStyle(AccentButtonStyle(enabled: canSend))
                    .disabled(model.isBusy || !canSend)
                }
            }

            boardPreview

            SplitRow {
                effectsPanel
            } aside: {
                inspector
            }

            firmwareZones
        }
    }

    // MARK: Preview

    private var boardPreview: some View {
        Card(padding: 0) {
            VStack(spacing: 0) {
                KeyboardView(colorFor: previewColor, isInteractive: false)
                    .padding(Theme.panelInset)
                    .accessibilityLabel("Lighting preview")
                Hairline()
                HStack(spacing: 0) {
                    ReadoutCell(label: "Effect") {
                        Text(lighting.mode.name).font(ReadoutFont.text)
                    }
                    Hairline(axis: .vertical)
                    ReadoutCell(label: "Mode") {
                        Text(String(format: "0x%02X", lighting.mode.rawValue)).font(ReadoutFont.mono)
                    }
                    Hairline(axis: .vertical)
                    ReadoutCell(label: "Color") {
                        if lighting.mode == .off || colorLocked {
                            Text(colorSourceText).font(ReadoutFont.text)
                        } else {
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(Color(lighting.color))
                                    .frame(width: 9, height: 9)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                                            .strokeBorder(Theme.strokeStrong, lineWidth: 1)
                                    )
                                Text("#\(lighting.color.hex)").font(ReadoutFont.mono)
                            }
                        }
                    }
                    Hairline(axis: .vertical)
                    ReadoutCell(label: "Brightness") {
                        Text("\(lighting.brightness) of 5").font(ReadoutFont.text).monospacedDigit()
                    }
                    Hairline(axis: .vertical)
                    ReadoutCell(label: "Speed") {
                        Text(lighting.mode.supportsSpeed ? "\(lighting.speed) of 5" : "Not used")
                            .font(ReadoutFont.text)
                            .monospacedDigit()
                            .foregroundStyle(lighting.mode.supportsSpeed ? Theme.text : Theme.tertiary)
                    }
                    Hairline(axis: .vertical)
                    ReadoutCell(label: "Direction") {
                        Text(lighting.mode.supportsDirection ? (lighting.direction == 0 ? "Forward" : "Reverse") : "Not used")
                            .font(ReadoutFont.text)
                            .foregroundStyle(lighting.mode.supportsDirection ? Theme.text : Theme.tertiary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
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
        let modes = LightingMode.allCases
        let rows = stride(from: 0, to: modes.count, by: padColumns).map {
            Array(modes[$0..<min($0 + padColumns, modes.count)])
        }
        return Card(padding: 0, fillHeight: true) {
            VStack(spacing: 0) {
                PanelHeaderBand("Effect", detail: "\(modes.count) built-in modes")
                // Pads stretch in both axes so the grid always fills the panel down to the
                // inspector's bottom edge.
                VStack(spacing: 8) {
                    ForEach(rows.indices, id: \.self) { row in
                        HStack(spacing: 8) {
                            ForEach(rows[row]) { mode in
                                EffectPad(mode: mode, isSelected: lighting.mode == mode) {
                                    model.setLightingMode(mode)
                                }
                            }
                        }
                    }
                }
                .padding(Theme.panelInset)
                .frame(maxHeight: .infinity)
            }
        }
    }

    // MARK: Inspector

    private var inspector: some View {
        Card(padding: 0, fillHeight: true) {
            VStack(spacing: 0) {
                PanelHeaderBand(lighting.mode.name, detail: colorSourceText) {
                    Button {
                        model.state.lighting = .default
                        model.setLightingMode(.rolling)
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(GhostButtonStyle())
                    // Center the button on the two-line title block instead of aligning its
                    // baseline, so this band stays the same height as the Effect band beside it.
                    .alignmentGuide(.firstTextBaseline) { _ in 10 }
                    .help("Reset lighting to defaults")
                    .accessibilityLabel("Reset lighting to defaults")
                }

                FormRow("Color", detail: colorLockReason) {
                    HStack(spacing: 8) {
                        ValueChip("#\(lighting.color.hex)", color: colorLocked ? Theme.tertiary : Theme.text)
                        // The native well insets its swatch inside its frame, so it never meets
                        // the trailing edge. Draw a flat swatch over it; clicks still open the
                        // system color panel through the well underneath.
                        ColorPicker("", selection: colorBinding, supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 40, height: 20)
                            .overlay {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color(lighting.color))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .strokeBorder(Theme.strokeStrong, lineWidth: 1)
                                    )
                                    .allowsHitTesting(false)
                            }
                            .disabled(colorLocked)
                            .opacity(colorLocked ? 0.35 : 1)
                            .accessibilityLabel("Effect color")
                    }
                }

                Hairline()

                FormRow("Colorful", detail: "Rainbow instead of a single color") {
                    Toggle("", isOn: Binding(
                        get: { model.state.lighting.colorful },
                        set: { model.state.lighting.colorful = $0 }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(Theme.accent)
                    .disabled(colorfulLocked)
                    .opacity(colorfulLocked ? 0.4 : 1)
                    .accessibilityLabel("Colorful")
                }

                Hairline()

                FormRow("Brightness") {
                    levelControl(
                        value: Binding(
                            get: { Double(model.state.lighting.brightness) },
                            set: { model.state.lighting.brightness = UInt8($0) }
                        ),
                        label: "\(lighting.brightness)",
                        enabled: true
                    )
                }

                Hairline()

                // Speed and direction stay visible when an effect ignores them, so the panel
                // keeps one shape while you browse effects.
                FormRow("Speed", detail: lighting.mode.supportsSpeed ? nil : "Not used by this effect") {
                    levelControl(
                        value: Binding(
                            get: { Double(model.state.lighting.speed) },
                            set: { model.state.lighting.speed = UInt8($0) }
                        ),
                        label: lighting.mode.supportsSpeed ? "\(lighting.speed)" : "–",
                        enabled: lighting.mode.supportsSpeed
                    )
                }

                Hairline()

                FormRow("Direction", detail: lighting.mode.supportsDirection ? nil : "Not used by this effect") {
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
                    .frame(width: controlWidth)
                    .disabled(!lighting.mode.supportsDirection)
                    .opacity(lighting.mode.supportsDirection ? 1 : 0.4)
                    .accessibilityLabel("Direction")
                }

                Spacer(minLength: 0)

                if !canSend {
                    Hairline()
                    Label("Connect the keyboard over USB-C to apply", systemImage: "cable.connector")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.secondary)
                        .frame(maxWidth: .infinity, minHeight: Theme.rowHeight, alignment: .leading)
                        .padding(.horizontal, Theme.panelInset)
                }
            }
        }
    }

    /// A 0–5 slider with its value chip on the trailing edge. The chip has a fixed width so the
    /// sliders in different rows end at the same x.
    private func levelControl(value: Binding<Double>, label: String, enabled: Bool) -> some View {
        HStack(spacing: 10) {
            Slider(value: value, in: 0...5, step: 1)
                .controlSize(.small)
                .tint(Theme.accent)
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.4)
            ValueChip(label, color: enabled ? Theme.text : Theme.tertiary)
                .frame(width: 22, alignment: .trailing)
        }
        .frame(width: controlWidth)
    }

    // MARK: Firmware-only zones

    private var firmwareZones: some View {
        Card(padding: 0) {
            VStack(spacing: 0) {
                PanelHeaderBand(
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
                .padding(.bottom, 4)
            }
        }
    }

    private func tableHeading(_ text: String) -> some View {
        Text(text)
            .font(Theme.captionFont)
            .foregroundStyle(Theme.tertiary)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .padding(.horizontal, Theme.panelInset)
    }

    @ViewBuilder
    private func shortcutRow(_ function: String, lightBar: [String]?, sideStrip: [String]?) -> some View {
        Hairline()
            .padding(.horizontal, Theme.panelInset)
            .gridCellUnsizedAxes(.horizontal)
        GridRow {
            Text(function)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, minHeight: Theme.rowHeight, alignment: .leading)
                .padding(.horizontal, Theme.panelInset)
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
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Theme.rowHeight, alignment: .leading)
        .padding(.horizontal, Theme.panelInset)
    }
}

/// One effect as a keycap-like pad: icon top left, mode code top right, name bottom left. Pads
/// stretch to share the grid's height, so the panel never leaves a void under the last row.
private struct EffectPad: View {
    let mode: LightingMode
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Image(systemName: mode.symbol)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(isSelected ? Theme.accent : Theme.secondary)
                        .frame(width: 18, height: 16, alignment: .leading)
                    Spacer(minLength: 4)
                    Text(String(format: "%02d", mode.rawValue))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(isSelected ? Theme.accent : Theme.tertiary)
                }
                Spacer(minLength: 6)
                Text(mode.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Theme.text : Theme.text.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.10) : (hovering ? Theme.cardRaised : Theme.field))
            )
            .overlay(alignment: .bottom) {
                // Darker skirt along the bottom edge, like the KeyTag chips, so pads read as keys.
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Color.black.opacity(isSelected ? 0.0 : 0.35))
                    .frame(height: 2)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 1)
            }
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent.opacity(0.85) : Theme.strokeStrong.opacity(hovering ? 1 : 0.7), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(mode.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// One column of the readout strip under the board: label on top, value below. Every cell has
/// the same insets and is top-aligned, so labels and values share baselines across the strip.
private enum ReadoutFont {
    static let text = Font.system(size: 12.5, weight: .medium)
    static let mono = Font.system(size: 12, weight: .medium, design: .monospaced)
}

private struct ReadoutCell<Value: View>: View {
    let label: String
    @ViewBuilder var value: Value

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.tertiary)
            value
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .frame(height: 16, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, Theme.panelInset)
        .padding(.vertical, 12)
    }
}
