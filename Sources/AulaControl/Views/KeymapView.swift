import SwiftUI
import AulaKit

struct KeymapView: View {
    @EnvironmentObject var model: AppModel

    private var map: KeyRemapMap {
        model.selectedLayer == .normal ? model.state.keymap : model.state.fnKeymap
    }

    private var selectedKey: KeyCap? {
        model.selectedKey.flatMap { KeyLayout.f108Pro.key(named: $0) } ?? KeyLayout.f108Pro.key(named: "capslock")
    }

    private var canWrite: Bool { model.canUseHardware || model.isPreview }

    /// Mapped keys in physical board order, so the list reads left to right like the keyboard.
    private var mappedKeysInOrder: [KeyCap] {
        KeyLayout.f108Pro.keys.filter { map[$0.name] != nil }
    }

    var body: some View {
        PageScroll {
            PageHeader(
                eyebrow: "USB-C",
                title: "Onboard keymap",
                subtitle: "Remaps are written to the keyboard's memory and work on any computer it is plugged into."
            ) {
                HStack(spacing: 10) {
                    StatusPill(
                        text: canWrite ? "\(map.count) remapped" : "USB-C required",
                        color: canWrite ? (map.isEmpty ? Theme.tertiary : Theme.accent) : Theme.secondary,
                        icon: canWrite ? nil : "cable.connector"
                    )
                    Button {
                        model.applyKeymap()
                    } label: {
                        Label("Apply keymap", systemImage: "arrow.down.to.line")
                    }
                    .buttonStyle(AccentButtonStyle(enabled: canWrite))
                    .disabled(model.isBusy || !canWrite)
                }
            }

            SplitRow {
                boardPanel
            } aside: {
                inspector
            }

            comparison
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("", selection: $model.selectedLayer) {
                ForEach(RemapLayer.allCases) { layer in
                    Text(layer.title).tag(layer)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 200)

            // The hint is the first thing to go when the column is too narrow for every control.
            ViewThatFits(in: .horizontal) {
                layerHint.fixedSize()
                Color.clear.frame(width: 0, height: 0)
            }
            .layoutPriority(-1)

            Spacer(minLength: 0)

            Menu {
                Button("Mac modifier layout") { apply(RemapPresets.mac) }
                Button("Caps Lock → Control") { apply(RemapPresets.capsToControl) }
                Button("WASD → Arrow keys") { apply(RemapPresets.wasdArrows) }
                Divider()
                Button("Reset layer") { reset() }
            } label: {
                Text("Presets")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button {
                model.resetOnboardKeymap()
            } label: {
                Label("Reset onboard", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(GhostButtonStyle())
            .fixedSize()
        }
    }

    @ViewBuilder
    private var layerHint: some View {
        HStack(spacing: 6) {
            if model.selectedLayer == .normal {
                Text("Active by default")
            } else {
                Text("Active while")
                KeyTag("Fn")
                Text("is held")
            }
        }
        .font(Theme.captionFont)
        .foregroundStyle(Theme.tertiary)
    }

    // MARK: - Board

    /// Layer controls, board, legend and the layer's mapping list. The layer controls live here
    /// because they change what the board shows. When the inspector is taller, the board band
    /// takes the spare height and keeps the keyboard centered in it, so the legend and mapping
    /// list stay on the bottom edge level with the inspector's footer.
    private var boardPanel: some View {
        Card(padding: 0, fillHeight: true) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeaderBand("Board", detail: "Select a key to change what it sends.")

                VStack(alignment: .leading, spacing: Theme.panelInset) {
                    toolbar
                    KeyboardView(
                        colorFor: { key in
                            guard map[key.name] != nil else { return nil }
                            // Warm graphite, just enough to separate remapped caps without reading as lit.
                            return AulaRGB(58, 47, 28)
                        },
                        selectedKey: selectedKey?.name,
                        mappedKeys: Set(map.keys),
                        showRemapDot: true,
                        onTap: { key in model.selectedKey = key.name }
                    )
                    .frame(maxHeight: .infinity)
                }
                .padding(Theme.panelInset)

                Hairline()

                legend
                    .frame(minHeight: Theme.rowHeight)
                    .padding(.horizontal, Theme.panelInset)

                Hairline()

                mappingList
                    .padding(Theme.panelInset)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Theme.accent)
                    .frame(width: 5, height: 5)
                    .frame(width: 10, height: 10)
                Text("Remapped")
            }
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(Theme.accent, lineWidth: 1.5)
                    .frame(width: 10, height: 10)
                Text("Selected")
            }
            Spacer(minLength: 12)
            Text("Unlisted keys keep their factory behavior.")
                .foregroundStyle(Theme.tertiary)
        }
        .font(Theme.captionFont)
        .foregroundStyle(Theme.secondary)
    }

    private var mappingList: some View {
        MappingList(title: "Mappings in this layer", keys: mappedKeysInOrder, map: map, selectedKey: selectedKey?.name) {
            model.selectedKey = $0
        }
    }

    // MARK: - Inspector

    private var inspector: some View {
        Card(fillHeight: true) {
            if let key = selectedKey {
                ActionEditor(
                    key: key,
                    current: map[key.name],
                    macros: model.state.macros,
                    onChange: { action in
                        model.setKeymap(key.name, action: action, layer: model.selectedLayer)
                    }
                )
                .id("\(key.name)-\(model.selectedLayer.rawValue)")
            } else {
                EmptyState(icon: "keyboard", title: "Select a key", message: "Click any key on the board to edit its behavior.")
            }
        }
    }

    // MARK: - Onboard vs. Mac Remap

    /// A two-column spec table. Every row is one `SpecRow`, so the onboard and Mac values always
    /// share a baseline and the columns share one leading edge.
    private var comparison: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeaderBand("Onboard keymap or Mac remap", detail: "Use Mac remap when the keyboard is on Bluetooth.")

                SpecRow(label: "", onboard: "Onboard keymap", mac: "Mac remap", style: .heading)
                Hairline()
                SpecRow(label: "Write over", onboard: "USB-C", mac: "Bluetooth or USB")
                Hairline()
                SpecRow(label: "Stored on", onboard: "Keyboard", mac: "This Mac")
                Hairline()
                SpecRow(label: "Works on", onboard: "Any computer", mac: "This Mac only")
                Hairline()
                SpecRow(
                    label: "Notes",
                    onboard: "Media actions and onboard macros keep working on other machines.",
                    mac: "Can run macros on this Mac. Needs Accessibility permission.",
                    style: .note
                )
            }
        }
    }

    // MARK: - Actions

    private func apply(_ preset: KeyRemapMap) {
        if model.selectedLayer == .normal {
            model.state.keymap = preset
        } else {
            model.state.fnKeymap = preset
        }
        model.showToast(.info, "Preset loaded. Press Apply keymap to write it to the keyboard.")
    }

    private func reset() {
        if model.selectedLayer == .normal { model.state.keymap = [:] }
        else { model.state.fnKeymap = [:] }
        model.showToast(.info, "Layer cleared locally. Press Apply keymap to write it.")
    }
}

/// One row of the comparison table: a label column, then the onboard and Mac values in two equal
/// columns.
private struct SpecRow: View {
    enum Style { case value, heading, note }

    let label: String
    let onboard: String
    let mac: String
    var style: Style = .value

    private static let labelWidth: CGFloat = 120

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(label)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.tertiary)
                .frame(width: Self.labelWidth, alignment: .leading)
            cell(onboard)
            cell(mac)
        }
        .padding(.horizontal, Theme.panelInset)
        .padding(.vertical, style == .note ? Theme.panelInset : 0)
        .frame(minHeight: style == .note ? nil : Theme.rowHeight)
    }

    private func cell(_ text: String) -> some View {
        Text(text)
            .font(font)
            .foregroundStyle(style == .note ? Theme.secondary : Theme.text)
            .lineSpacing(style == .note ? 2 : 0)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, Theme.panelInset)
    }

    private var font: Font {
        switch style {
        case .heading: return Theme.sectionFont
        case .value: return Theme.bodyFont.weight(.medium)
        case .note: return Theme.captionFont
        }
    }
}
