import SwiftUI
import AulaKit

struct PerKeyView: View {
    @EnvironmentObject var model: AppModel

    private let palette: [AulaRGB] = [
        AulaRGB(255, 72, 66), AulaRGB(255, 149, 48), AulaRGB(255, 214, 74),
        AulaRGB(109, 222, 154), AulaRGB(78, 214, 192), AulaRGB(90, 168, 255),
        AulaRGB(160, 122, 255), AulaRGB(255, 255, 255),
    ]

    private var selectedKey: KeyCap? {
        model.selectedKey.flatMap { KeyLayout.f108Pro.key(named: $0) }
    }

    private var selectedColor: AulaRGB {
        guard let key = selectedKey else { return .white }
        return model.state.perKey[key.name] ?? AulaRGB(30, 34, 42)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    eyebrow: "HARDWARE · USB",
                    title: "Per-key studio",
                    subtitle: "Paint the whole board key by key. The keyboard stores one frame of 104 colors and keeps them after you unplug."
                ) {
                    HStack(spacing: 10) {
                        StatusPill(
                            text: model.canUseHardware || model.isPreview ? "Ready to send" : "USB-C required",
                            color: model.canUseHardware || model.isPreview ? Theme.success : Theme.accent,
                            icon: model.canUseHardware || model.isPreview ? "checkmark" : "cable.connector"
                        )
                        Button {
                            model.applyPerKey()
                        } label: {
                            Label("Apply colors", systemImage: "arrow.down.to.line")
                        }
                        .buttonStyle(AccentButtonStyle(enabled: model.canUseHardware || model.isPreview))
                        .disabled(model.isBusy || !(model.canUseHardware || model.isPreview))
                    }
                }

                Card(padding: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Click a key to paint it")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.secondary)
                            Spacer()
                            if !model.state.perKey.isEmpty {
                                Text("\(model.state.perKey.count) keys painted")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Theme.accent)
                            } else {
                                Text("All keys off")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Theme.tertiary)
                            }
                        }

                        KeyboardView(
                            colorFor: { key in model.state.perKey[key.name] },
                            selectedKey: model.selectedKey,
                            onTap: { key in model.selectedKey = key.name }
                        )
                        .padding(.horizontal, 4)

                        HStack(spacing: 16) {
                            legend(color: Theme.accent, text: "Selected")
                            legend(color: Color.white.opacity(0.18), text: "Unpainted — off")
                            Spacer()
                            Text("Colors are written as a complete frame; unpainted keys are dark.")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.tertiary)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 18) {
                    inspector
                        .frame(maxWidth: .infinity)
                    presets
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(text).font(.system(size: 10)).foregroundStyle(Theme.tertiary)
        }
    }

    private var inspector: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedKey.map { KeyLayout.f108Pro.key(named: $0.name)?.label ?? $0.name } ?? "No key selected")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.text)
                        Text(selectedKey.map { "\($0.name) · light index \($0.light)" } ?? "Pick any key on the board")
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.tertiary)
                    }
                    Spacer()
                    if let selectedKey {
                        Button {
                            model.clearPerKey(selectedKey)
                        } label: {
                            Label("Clear", systemImage: "xmark")
                        }
                        .buttonStyle(GhostButtonStyle())
                    }
                }

                HStack(spacing: 14) {
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
                    .frame(width: 44, height: 44)
                    .disabled(selectedKey == nil)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Key color")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Theme.secondary)
                        Text("#\(selectedColor.hex)")
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.text)
                    }
                    Spacer()
                }

                HStack(spacing: 8) {
                    ForEach(Array(palette.enumerated()), id: \.offset) { _, color in
                        Button {
                            guard let key = selectedKey else { return }
                            model.setPerKey(key, color: color)
                        } label: {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color(color))
                                .frame(height: 26)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedKey == nil)
                        .opacity(selectedKey == nil ? 0.4 : 1)
                    }
                }

                Rectangle().fill(Theme.stroke).frame(height: 1)

                SliderRow(
                    title: "Global brightness",
                    value: Binding(
                        get: { Double(model.state.perKeyBrightness) },
                        set: { model.state.perKeyBrightness = UInt8($0) }
                    ),
                    range: 0...5, step: 1,
                    valueLabel: "\(model.state.perKeyBrightness)"
                )

                HStack(spacing: 10) {
                    Button {
                        model.applyPerKey()
                    } label: {
                        Label("Apply to keyboard", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AccentButtonStyle(enabled: model.canUseHardware || model.isPreview))
                    .disabled(model.isBusy || !(model.canUseHardware || model.isPreview))

                    Button {
                        model.clearAllPerKey()
                    } label: {
                        Text("Clear all")
                    }
                    .buttonStyle(GhostButtonStyle())
                }
            }
        }
    }

    private var presets: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Presets")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("A starting point for the whole board.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.secondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(PerKeyPreset.all) { preset in
                        Button {
                            model.applyPerKeyPreset(preset)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: preset.symbol)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.accent)
                                Text(preset.name)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(Theme.text)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Color.white.opacity(0.028))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .strokeBorder(Theme.stroke, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        model.fillPerKey(AulaRGB(255, 176, 32))
                    } label: {
                        Label("Fill all", systemImage: "square.fill")
                    }
                    .buttonStyle(GhostButtonStyle())

                    Button {
                        model.clearAllPerKey()
                    } label: {
                        Label("Dark", systemImage: "moon.fill")
                    }
                    .buttonStyle(GhostButtonStyle())
                }

                Text("Tip: use the Mac Remap page for per-key behavior that works over Bluetooth. Per-key RGB is firmware-side and needs USB.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.tertiary)
                    .lineSpacing(2)
            }
        }
    }
}
