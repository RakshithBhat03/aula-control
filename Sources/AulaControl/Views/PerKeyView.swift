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
        PageScroll {
            PageHeader(
                eyebrow: "USB-C",
                title: "Per-key RGB",
                subtitle: "Set a color for each key. The keyboard keeps the frame after unplugging."
            ) {
                HStack(spacing: 10) {
                    StatusPill(
                        text: canSend ? "Ready to send" : "USB-C required",
                        color: canSend ? Theme.success : Theme.secondary,
                        icon: canSend ? nil : "cable.connector"
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

            SplitRow {
                presets
            } aside: {
                inspector
            }
        }
    }

    // MARK: Board

    private var board: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeaderBand("Board", detail: "Click a key to select it, then choose a color.") {
                    HStack(spacing: 6) {
                        Text("Painted")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.secondary)
                        ValueChip("\(model.state.perKey.count)/\(keyCount)")
                    }
                }

                KeyboardView(
                    colorFor: { key in model.state.perKey[key.name] },
                    selectedKey: model.selectedKey,
                    onTap: { key in model.selectedKey = key.name }
                )
                .padding(Theme.panelInset)

                Hairline()

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
                .frame(minHeight: Theme.rowHeight)
                .padding(.horizontal, Theme.panelInset)
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
        Card(padding: 0, fillHeight: true) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeaderBand(selectedKey.map(Self.title(for:)) ?? "No key selected", detail: keyStatus)

                KeyReadoutStrip(cells: [
                    ("Key", selectedKey?.name ?? "–"),
                    ("LED", selectedKey.map { String(format: "%03d", $0.light) } ?? "–"),
                    ("Color", selectedKey == nil ? "–" : "#\(selectedColor.hex)"),
                ])
                .padding(Theme.panelInset)

                Hairline()

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        fieldLabel("Color")
                        Spacer(minLength: 8)
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
                        .fixedSize()
                        .disabled(selectedKey == nil)
                        .help("Choose any color")
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
                .padding(Theme.panelInset)

                Hairline()

                SliderRow(
                    title: "Global brightness",
                    value: Binding(
                        get: { Double(model.state.perKeyBrightness) },
                        set: { model.state.perKeyBrightness = UInt8($0) }
                    ),
                    range: 0...5, step: 1,
                    valueLabel: "\(model.state.perKeyBrightness)/5"
                )
                .padding(Theme.panelInset)

                Spacer(minLength: 0)

                Hairline()

                HStack(spacing: 12) {
                    Button {
                        if let selectedKey { model.clearPerKey(selectedKey) }
                    } label: {
                        Label("Clear key", systemImage: "xmark")
                    }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(selectedKey == nil)
                    .help("Turn this key off")
                    Spacer(minLength: 8)
                    Text("Sent when you apply colors")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.tertiary)
                }
                .padding(Theme.panelInset)
            }
        }
    }

    private var keyStatus: String {
        guard let key = selectedKey else { return "Select a key on the board." }
        return model.state.perKey[key.name] == nil ? "Unpainted, off" : "Painted"
    }

    private static func title(for key: KeyCap) -> String {
        key.label.isEmpty ? key.name.capitalized : key.label
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.secondary)
    }

    // MARK: Presets

    /// Preset tiles stretch to fill the column, so this panel always ends level with the inspector.
    private var presets: some View {
        Card(padding: 0, fillHeight: true) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeaderBand("Presets", detail: "Replaces the colors of every key.")

                let tiles = presetTiles
                VStack(spacing: 8) {
                    ForEach(0..<(tiles.count + 1) / 2, id: \.self) { row in
                        HStack(spacing: 8) {
                            ForEach(tiles.indices.filter { $0 / 2 == row }, id: \.self) { index in
                                presetTile(tiles[index])
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(Theme.panelInset)

                Hairline()

                Text("Per-key RGB is stored in firmware and needs USB-C. For per-key behavior over Bluetooth, use Mac remap.")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.tertiary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(Theme.panelInset)
            }
        }
    }

    private struct PresetTile {
        let name: String
        let swatches: [AulaRGB]
        let isSelected: Bool
        let action: () -> Void
    }

    private var presetTiles: [PresetTile] {
        var tiles = PerKeyPreset.all.map { preset in
            let colors = preset.colors()
            return PresetTile(
                name: preset.name,
                swatches: Self.swatches(for: colors),
                isSelected: !colors.isEmpty && model.state.perKey == colors,
                action: { model.applyPerKeyPreset(preset) }
            )
        }
        tiles.append(PresetTile(
            name: "Fill all",
            swatches: [fillColor],
            isSelected: isFilledWithDefault,
            action: { model.fillPerKey(fillColor) }
        ))
        tiles.append(PresetTile(
            name: "Clear all",
            swatches: [],
            isSelected: model.state.perKey.isEmpty,
            action: { model.clearAllPerKey() }
        ))
        return tiles
    }

    private func presetTile(_ tile: PresetTile) -> some View {
        SelectableTile(isSelected: tile.isSelected, action: tile.action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(tile.name)
                        .font(.system(size: 12.5, weight: tile.isSelected ? .semibold : .medium))
                        .foregroundStyle(Theme.text)
                    Spacer(minLength: 8)
                    if tile.swatches.isEmpty {
                        Text("All keys off")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.tertiary)
                    }
                }
                Spacer(minLength: 0)
                PresetStrip(colors: tile.swatches.isEmpty ? [unlitColor] : tile.swatches)
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxHeight: .infinity)
    }

    private var isFilledWithDefault: Bool {
        let painted = model.state.perKey
        return painted.count == keyCount && painted.values.allSatisfy { $0 == fillColor }
    }

    /// The distinct colors a preset uses, in board order, so each tile previews what it will paint.
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

/// A full-width bar of equal segments previewing a preset's colors.
private struct PresetStrip: View {
    let colors: [AulaRGB]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color(color))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    )
            }
        }
        .frame(height: 10)
    }
}

/// One palette color. The selection ring is drawn inside the swatch so the row keeps exact edges.
private struct PaletteSwatch: View {
    let color: AulaRGB
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(color))
                .frame(height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(
                            isSelected ? Theme.accent : (hovering ? Theme.strokeStrong : Theme.stroke),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .strokeBorder(Color.black.opacity(isSelected ? 0.55 : 0), lineWidth: 1)
                        .padding(2)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("#\(color.hex)")
        .accessibilityLabel("Color #\(color.hex)")
    }
}
