import SwiftUI
import AulaKit

struct PerKeyView: View {
    @EnvironmentObject var model: AppModel

    private let palette: [AulaRGB] = [
        AulaRGB(255, 72, 66), AulaRGB(255, 149, 48), AulaRGB(255, 214, 74),
        AulaRGB(109, 222, 154), AulaRGB(78, 214, 192), AulaRGB(90, 168, 255),
        AulaRGB(160, 122, 255), AulaRGB(255, 255, 255),
    ]

    private let fillColor = AulaRGB(255, 176, 32)
    private let unlitColor = AulaRGB(30, 34, 42)

    private var selectedKey: KeyCap? {
        model.selectedKey.flatMap { KeyLayout.f108Pro.key(named: $0) }
    }

    private var selectedColor: AulaRGB {
        guard let key = selectedKey else { return .white }
        return model.state.perKey[key.name] ?? unlitColor
    }

    private var canSend: Bool { model.canUseHardware || model.isPreview }

    private var keyCount: Int { KeyLayout.f108Pro.keys.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    eyebrow: "USB-C",
                    title: "Per-key RGB",
                    subtitle: "Set a color for each key. The keyboard stores one 104-key frame and keeps it after unplugging."
                ) {
                    HStack(spacing: 10) {
                        StatusPill(
                            text: canSend ? "Ready to send" : "USB-C required",
                            color: canSend ? Theme.success : Theme.secondary,
                            icon: canSend ? "checkmark" : "cable.connector"
                        )
                        Button {
                            model.applyPerKey()
                        } label: {
                            Label("Apply colors", systemImage: "arrow.down.to.line")
                        }
                        .buttonStyle(AccentButtonStyle(enabled: canSend))
                        .disabled(model.isBusy || !canSend)
                    }
                }

                board

                HStack(alignment: .top, spacing: 16) {
                    inspector
                        .frame(maxWidth: .infinity)
                    presets
                        .frame(width: 300)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Board

    private var board: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                PanelHeader("Board", detail: "Click a key to select it, then choose a color.") {
                    if model.state.perKey.isEmpty {
                        Text("All keys off")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.tertiary)
                    } else {
                        HStack(spacing: 6) {
                            Text("Painted")
                                .font(Theme.captionFont)
                                .foregroundStyle(Theme.secondary)
                            ValueChip("\(model.state.perKey.count)/\(keyCount)")
                        }
                    }
                }

                KeyboardView(
                    colorFor: { key in model.state.perKey[key.name] },
                    selectedKey: model.selectedKey,
                    onTap: { key in model.selectedKey = key.name }
                )

                Rectangle().fill(Theme.stroke).frame(height: 1)

                HStack(spacing: 16) {
                    legend(text: "Selected") {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(Theme.accent, lineWidth: 1.5)
                    }
                    legend(text: "Unpainted, off") {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Theme.cardRaised)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .strokeBorder(Theme.strokeStrong, lineWidth: 1)
                            )
                    }
                    Spacer(minLength: 12)
                    Text("Sent as one full frame. Unpainted keys stay dark.")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.tertiary)
                }
            }
        }
    }

    private func legend(text: String, @ViewBuilder swatch: () -> some View) -> some View {
        HStack(spacing: 6) {
            swatch().frame(width: 10, height: 10)
            Text(text)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.secondary)
        }
    }

    // MARK: Inspector

    private var inspector: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedKey?.label ?? "No key selected")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Text(selectedKey.map { "\($0.name) · index \($0.light)" } ?? "Select a key on the board")
                            .font(Theme.monoFont)
                            .foregroundStyle(Theme.tertiary)
                    }
                    Spacer()
                    if let selectedKey {
                        Button {
                            model.clearPerKey(selectedKey)
                        } label: {
                            Label("Clear key", systemImage: "xmark")
                        }
                        .buttonStyle(GhostButtonStyle())
                        .help("Turn this key off")
                    }
                }
                .padding(16)

                divider

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        ColorPicker(
                            "",
                            selection: Binding(
                                get: { Color(selectedColor) },
                                set: { newColor in
                                    guard let key = selectedKey else { return }
                                    model.setPerKey(key, color: AulaRGB(newColor))
                                }
                            ),
                            supportsOpacity: false
                        )
                        .labelsHidden()
                        .frame(width: 44, height: 28)
                        .disabled(selectedKey == nil)

                        Text("Color")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.secondary)
                        ValueChip("#\(selectedColor.hex)")
                        Spacer()
                    }

                    HStack(spacing: 6) {
                        ForEach(Array(palette.enumerated()), id: \.offset) { _, color in
                            PaletteSwatch(
                                color: color,
                                isSelected: selectedKey != nil && selectedColor == color
                            ) {
                                guard let key = selectedKey else { return }
                                model.setPerKey(key, color: color)
                            }
                            .disabled(selectedKey == nil)
                            .opacity(selectedKey == nil ? 0.4 : 1)
                        }
                    }
                }
                .padding(16)

                divider

                SliderRow(
                    title: "Global brightness",
                    value: Binding(
                        get: { Double(model.state.perKeyBrightness) },
                        set: { model.state.perKeyBrightness = UInt8($0) }
                    ),
                    range: 0...5, step: 1,
                    valueLabel: "\(model.state.perKeyBrightness)/5"
                )
                .padding(16)

                divider

                HStack(spacing: 8) {
                    Button {
                        model.clearAllPerKey()
                    } label: {
                        Text("Clear all")
                    }
                    .buttonStyle(GhostButtonStyle())
                    Spacer()
                    Button {
                        model.applyPerKey()
                    } label: {
                        Label("Apply to keyboard", systemImage: "checkmark")
                    }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(model.isBusy || !canSend)
                    .opacity(canSend ? 1 : 0.4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.stroke).frame(height: 1)
    }

    // MARK: Presets

    private var presets: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader("Presets", detail: "Replaces the colors of every key.")

                VStack(spacing: 6) {
                    ForEach(PerKeyPreset.all) { preset in
                        let colors = preset.colors()
                        SelectableTile(isSelected: !colors.isEmpty && model.state.perKey == colors) {
                            model.applyPerKeyPreset(preset)
                        } label: {
                            PresetRowLabel(name: preset.name, swatches: Self.swatches(for: colors))
                        }
                    }

                    SelectableTile(isSelected: isFilledWithDefault) {
                        model.fillPerKey(fillColor)
                    } label: {
                        PresetRowLabel(name: "Fill all", swatches: [fillColor])
                    }

                    SelectableTile(isSelected: model.state.perKey.isEmpty) {
                        model.clearAllPerKey()
                    } label: {
                        PresetRowLabel(name: "Dark", swatches: [])
                    }
                }

                divider

                Text("Per-key RGB is stored in firmware and needs USB-C. For per-key behavior over Bluetooth, use Mac Remap.")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.tertiary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var isFilledWithDefault: Bool {
        let painted = model.state.perKey
        return painted.count == keyCount && painted.values.allSatisfy { $0 == fillColor }
    }

    /// The distinct colors a preset uses, in board order, so each row previews what it will paint.
    private static func swatches(for colors: [String: AulaRGB]) -> [AulaRGB] {
        var seen = Set<AulaRGB>()
        var result: [AulaRGB] = []
        for key in KeyLayout.f108Pro.keys {
            guard let color = colors[key.name], seen.insert(color).inserted else { continue }
            result.append(color)
            if result.count == 6 { break }
        }
        return result
    }
}

private struct PresetRowLabel: View {
    let name: String
    let swatches: [AulaRGB]

    var body: some View {
        HStack(spacing: 10) {
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text)
            Spacer(minLength: 8)
            if swatches.isEmpty {
                Text("off")
                    .font(Theme.monoFont)
                    .foregroundStyle(Theme.tertiary)
            } else {
                HStack(spacing: 2) {
                    ForEach(Array(swatches.enumerated()), id: \.offset) { _, color in
                        Rectangle()
                            .fill(Color(color))
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(1)
                .overlay(Rectangle().strokeBorder(Theme.stroke, lineWidth: 1))
            }
        }
    }
}

private struct PaletteSwatch: View {
    let color: AulaRGB
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(color))
                .frame(height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(hovering ? Theme.strokeStrong : Theme.stroke, lineWidth: 1)
                )
                .padding(2)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isSelected ? Theme.accent : Color.clear, lineWidth: 1.5)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("#\(color.hex)")
        .accessibilityLabel("Color #\(color.hex)")
    }
}
