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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    eyebrow: "HARDWARE · USB",
                    title: "Onboard keymap",
                    subtitle: "Remap keys inside the keyboard itself. The mapping is stored on the F108 Pro and travels with it — even to a Windows PC."
                ) {
                    HStack(spacing: 10) {
                        StatusPill(
                            text: model.canUseHardware || model.isPreview ? "\(map.count) remapped" : "USB-C required",
                            color: model.canUseHardware || model.isPreview ? (map.isEmpty ? Theme.tertiary : Theme.accent) : Theme.accent,
                            icon: model.canUseHardware || model.isPreview ? "keyboard" : "cable.connector"
                        )
                        Button {
                            model.applyKeymap()
                        } label: {
                            Label("Apply keymap", systemImage: "arrow.down.to.line")
                        }
                        .buttonStyle(AccentButtonStyle(enabled: model.canUseHardware || model.isPreview))
                        .disabled(model.isBusy || !(model.canUseHardware || model.isPreview))
                    }
                }

                HStack(spacing: 12) {
                    Picker("", selection: $model.selectedLayer) {
                        ForEach(RemapLayer.allCases) { layer in
                            Text(layer.title).tag(layer)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 230)

                    Spacer()

                    Menu {
                        Button("Mac modifier layout") { apply(RemapPresets.mac) }
                        Button("Caps Lock → Control") { apply(RemapPresets.capsToControl) }
                        Button("WASD → Arrow keys") { apply(RemapPresets.wasdArrows) }
                        Divider()
                        Button("Reset layer") { reset() }
                    } label: {
                        Label("Presets", systemImage: "sparkles")
                            .font(.system(size: 11.5, weight: .medium))
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

                HStack(alignment: .top, spacing: 18) {
                    Card(padding: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(model.selectedLayer == .normal ? "Normal layer" : "FN layer")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.text)
                                Text("·")
                                    .foregroundStyle(Theme.tertiary)
                                Text("Click a key to change what it sends")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.secondary)
                                Spacer()
                                if !map.isEmpty {
                                    Text("\(map.count) ACTIVE")
                                        .font(.system(size: 9, weight: .semibold))
                                        .tracking(0.8)
                                        .foregroundStyle(Theme.accent)
                                }
                            }

                            KeyboardView(
                                colorFor: { key in
                                    guard map[key.name] != nil else { return nil }
                                    return AulaRGB(68, 56, 28)
                                },
                                selectedKey: selectedKey?.name,
                                mappedKeys: Set(map.keys),
                                showRemapDot: true,
                                onTap: { key in model.selectedKey = key.name }
                            )
                            .padding(.horizontal, 4)

                            HStack(spacing: 16) {
                                HStack(spacing: 5) {
                                    Circle().fill(Theme.accent).frame(width: 5, height: 5)
                                    Text("Remapped key").font(.system(size: 10)).foregroundStyle(Theme.tertiary)
                                }
                                Spacer()
                                Text("Unlisted keys keep their factory behavior.")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.tertiary)
                            }
                        }
                    }

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
                    .frame(width: 330)
                }

                Card {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Onboard vs. macOS remapping")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Text("This page writes to the keyboard's own memory, so it needs USB. For remapping that works over Bluetooth and can run macros on this Mac, use the Mac Remap page. Onboard media actions and macros keep working when the keyboard is connected to another computer.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(Theme.secondary)
                                .lineSpacing(2.5)
                        }
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
    }

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
