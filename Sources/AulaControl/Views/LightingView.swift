import SwiftUI
import AulaKit

struct LightingView: View {
    @EnvironmentObject var model: AppModel

    private var lighting: LightingConfig { model.state.lighting }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(model.state.lighting.color) },
            set: { model.state.lighting.color = AulaRGB($0) }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    eyebrow: "HARDWARE · USB",
                    title: "Lighting",
                    subtitle: "Twenty firmware effects with color, brightness, speed and direction. Settings are stored on the keyboard, so they follow it between machines."
                ) {
                    HStack(spacing: 10) {
                        StatusPill(
                            text: model.canUseHardware || model.isPreview ? "Ready to send" : "USB-C required",
                            color: model.canUseHardware || model.isPreview ? Theme.success : Theme.accent,
                            icon: model.canUseHardware || model.isPreview ? "checkmark" : "cable.connector"
                        )
                        Button {
                            model.applyLighting()
                        } label: {
                            Label("Apply lighting", systemImage: "arrow.down.to.line")
                        }
                        .buttonStyle(AccentButtonStyle(enabled: model.canUseHardware || model.isPreview))
                        .disabled(model.isBusy || !(model.canUseHardware || model.isPreview))
                    }
                }

                HStack(alignment: .top, spacing: 18) {
                    effectsPanel
                    controlsPanel
                        .frame(width: 340)
                }

                firmwareZones
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
    }

    private var effectsPanel: some View {
        Card(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Effects")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Text("Pick a firmware mode")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.secondary)
                    }
                    Spacer()
                    Text("\(LightingMode.allCases.count) MODES")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(Theme.tertiary)
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 118), spacing: 10)],
                    spacing: 10
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
        return Button {
            model.setLightingMode(mode)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: mode.symbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(selected ? Theme.accent : Theme.secondary)
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.accent)
                    }
                }
                Text(mode.name)
                    .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? Theme.text : Theme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(selected ? Theme.accent.opacity(0.09) : Color.white.opacity(0.028))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(selected ? Theme.accent.opacity(0.55) : Theme.stroke, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var controlsPanel: some View {
        Card(padding: 20) {
            VStack(alignment: .leading, spacing: 18) {
                preview

                VStack(alignment: .leading, spacing: 12) {
                    Text("Effect settings")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.text)

                    HStack {
                        Text("Color")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.secondary)
                        Spacer()
                        Text("#\(lighting.color.hex)")
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.tertiary)
                        ColorPicker("", selection: colorBinding, supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 30)
                            .disabled(!lighting.mode.supportsColor || lighting.colorful)
                            .opacity(!lighting.mode.supportsColor || lighting.colorful ? 0.35 : 1)
                    }

                    ToggleRow(
                        title: "Colorful",
                        subtitle: "Rainbow instead of a single color",
                        isOn: Binding(
                            get: { model.state.lighting.colorful },
                            set: { model.state.lighting.colorful = $0 }
                        )
                    )
                    .disabled(!lighting.mode.supportsColor || lighting.mode.forcesRainbow)
                    .opacity(!lighting.mode.supportsColor || lighting.mode.forcesRainbow ? 0.4 : 1)

                    SliderRow(
                        title: "Brightness",
                        value: Binding(
                            get: { Double(model.state.lighting.brightness) },
                            set: { model.state.lighting.brightness = UInt8($0) }
                        ),
                        range: 0...5, step: 1,
                        valueLabel: "\(lighting.brightness)"
                    )

                    if lighting.mode.supportsSpeed {
                        SliderRow(
                            title: "Speed",
                            value: Binding(
                                get: { Double(model.state.lighting.speed) },
                                set: { model.state.lighting.speed = UInt8($0) }
                            ),
                            range: 0...5, step: 1,
                            valueLabel: "\(lighting.speed)"
                        )
                    }

                    if lighting.mode.supportsDirection {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Direction")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.secondary)
                            Picker("", selection: Binding(
                                get: { model.state.lighting.direction },
                                set: { model.state.lighting.direction = $0 }
                            )) {
                                Text("Forward").tag(UInt8(0))
                                Text("Reverse").tag(UInt8(1))
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }
                }

                Rectangle().fill(Theme.stroke).frame(height: 1)

                HStack(spacing: 10) {
                    Button {
                        model.applyLighting()
                    } label: {
                        Label("Apply", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AccentButtonStyle(enabled: model.canUseHardware || model.isPreview))
                    .disabled(model.isBusy || !(model.canUseHardware || model.isPreview))

                    Button {
                        model.state.lighting = .default
                        model.setLightingMode(.rolling)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(GhostButtonStyle())
                    .help("Reset to defaults")
                }

                if !model.canUseHardware && !model.isPreview {
                    Label("Connect USB-C to apply", systemImage: "cable.connector")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Theme.accent.opacity(0.9))
                }
            }
        }
    }

    private var preview: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(previewGradient)
                .frame(height: 132)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
                .overlay(
                    LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .center, endPoint: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                )
                .overlay(alignment: .topTrailing) {
                    Image(systemName: lighting.mode.symbol)
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(16)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(lighting.mode.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(lighting.mode.forcesRainbow ? "Built-in rainbow" : (lighting.colorful ? "Colorful" : "Single color"))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(14)
        }
    }

    private var previewGradient: LinearGradient {
        if lighting.mode == .off {
            return LinearGradient(colors: [Color(hex: 0x15181D), Color(hex: 0x0D0F13)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if lighting.mode.forcesRainbow || lighting.colorful {
            return LinearGradient(
                colors: [
                    Color(hex: 0xFF4D4D), Color(hex: 0xFFB020), Color(hex: 0x6DDE9A),
                    Color(hex: 0x4ED6C0), Color(hex: 0x6AA8FF), Color(hex: 0xB678FF)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color(lighting.color).opacity(0.95),
                Color(lighting.color).opacity(0.5),
                Color(hex: 0x15181D)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var firmwareZones: some View {
        Card {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 7) {
                        Image(systemName: "light.beacon.max")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                        Text("Light bar & side strips")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.text)
                    }
                    Text("These two zones live on a separate controller. The vendor app cannot change them, and neither can this one — use the firmware shortcuts.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.secondary)
                        .frame(maxWidth: 450, alignment: .leading)
                }
                Spacer(minLength: 10)
                VStack(alignment: .leading, spacing: 7) {
                    shortcut("Fn + L-Shift", "Light bar effect")
                    shortcut("Fn + L-Alt", "Light bar brightness")
                    shortcut("Fn + L-Ctrl", "Light bar speed")
                }
                VStack(alignment: .leading, spacing: 7) {
                    shortcut("Fn + R-Shift", "Side strip effect")
                    shortcut("Fn + R-Alt", "Side strip brightness")
                    shortcut("Fn + /", "Side strip color")
                }
            }
        }
    }

    private func shortcut(_ keys: String, _ label: String) -> some View {
        HStack(spacing: 8) {
            Text(keys)
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)))
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.secondary)
        }
    }
}
