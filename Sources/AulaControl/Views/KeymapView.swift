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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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

                toolbar

                HStack(alignment: .top, spacing: 16) {
                    boardPanel
                    inspector
                        .frame(width: 330)
                }

                comparison
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 14) {
            Picker("", selection: $model.selectedLayer) {
                ForEach(RemapLayer.allCases) { layer in
                    Text(layer.title).tag(layer)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 230)

            layerHint

            Spacer()

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

    private var boardPanel: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeader(model.selectedLayer.title, detail: "Select a key to change what it sends.") {
                    if !map.isEmpty {
                        ValueChip("\(map.count) mapped")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

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
                .padding(.horizontal, 12)
                .padding(.bottom, 12)

                hairline

                legend
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                if !mappedKeysInOrder.isEmpty {
                    hairline
                    mappingList
                        .padding(16)
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Theme.accent)
                    .frame(width: 5, height: 5)
                Text("Remapped")
            }
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(Theme.accent, lineWidth: 1.25)
                    .frame(width: 10, height: 10)
                Text("Selected")
            }
            Spacer()
            Text("Unlisted keys keep their factory behavior.")
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.tertiary)
    }

    private var mappingList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mappings in this layer")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.secondary)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 170), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(mappedKeysInOrder) { key in
                    if let action = map[key.name] {
                        MappingRow(
                            source: key,
                            action: action,
                            isSelected: selectedKey?.name == key.name
                        ) {
                            model.selectedKey = key.name
                        }
                    }
                }
            }
        }
    }

    // MARK: - Inspector

    private var inspector: some View {
        Card {
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

    private var comparison: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeader("Onboard keymap or Mac Remap", detail: "Use the Mac Remap page when the keyboard is on Bluetooth.")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                hairline

                HStack(alignment: .top, spacing: 0) {
                    SpecColumn(
                        title: "Onboard keymap",
                        rows: [
                            ("Write over", "USB-C"),
                            ("Stored on", "Keyboard"),
                            ("Works on", "Any computer"),
                        ],
                        note: "Media actions and onboard macros keep working on other machines."
                    )
                    Rectangle()
                        .fill(Theme.stroke)
                        .frame(width: 1)
                    SpecColumn(
                        title: "Mac Remap",
                        rows: [
                            ("Write over", "Bluetooth or USB"),
                            ("Stored on", "This Mac"),
                            ("Works on", "This Mac only"),
                        ],
                        note: "Can run macros on this Mac. Needs Accessibility permission."
                    )
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(height: 1)
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

/// One source key and what it now sends. Clicking it selects the key, mirroring a tap on the board.
private struct MappingRow: View {
    let source: KeyCap
    let action: KeyAction
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 7) {
                KeyTag(source.label.isEmpty ? source.name : source.label)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiary)
                Text(action.displayName)
                    .font(Theme.monoFont)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.10) : (hovering ? Theme.cardRaised : Theme.field))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent.opacity(0.85) : Theme.stroke, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("\(source.name) sends \(action.displayName)")
        .accessibilityLabel("\(source.label) key sends \(action.displayName)")
    }
}

/// A labeled spec column: key/value rows with mono values, then a one-line note.
private struct SpecColumn: View {
    let title: String
    let rows: [(String, String)]
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.text)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(rows, id: \.0) { label, value in
                    HStack(spacing: 8) {
                        Text(label)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.tertiary)
                            .frame(width: 74, alignment: .leading)
                        Text(value)
                            .font(Theme.monoFont)
                            .foregroundStyle(Theme.text)
                    }
                }
            }
            Text(note)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
}
