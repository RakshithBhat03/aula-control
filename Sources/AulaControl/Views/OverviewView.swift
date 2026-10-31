import SwiftUI
import AulaKit

struct OverviewView: View {
    @EnvironmentObject var model: AppModel

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if model.connection.kind != .wired && !model.isPreview {
                    connectionBanner
                }

                PageHeader(
                    eyebrow: "AULA F108 PRO",
                    title: "\(greeting).",
                    subtitle: "Every setting the Windows app offers — lighting, per-key color, onboard remapping and macros — rebuilt as a native Mac app."
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
                    }
                }

                hero

                HStack(spacing: 16) {
                    quickBrightness
                    quickEffect
                    quickMacRemap
                }

                worksWhere

                HStack(spacing: 16) {
                    fnCheatSheet
                    nextSteps
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
    }

    private var connectionBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.14)).frame(width: 38, height: 38)
                Image(systemName: "cable.connector")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(model.connection.kind == .absent ? "Keyboard not connected" : "You're on Bluetooth")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(model.connection.kind == .absent
                     ? "Connect with USB-C (Fn + 4) or pair over Bluetooth from the macOS menu bar."
                     : "Typing and macOS remapping work now. Lighting, per-key RGB and onboard settings need the wired connection.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.secondary)
            }
            Spacer()
            Text("Fn + 4  =  USB")
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.accent.opacity(0.10)))
                .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.2), lineWidth: 1))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.accent.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.accent.opacity(0.16), lineWidth: 1)
        )
    }

    private var hero: some View {
        Card(padding: 0) {
            HStack(alignment: .center, spacing: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Text("MAC-NATIVE CONTROL")
                            .font(.system(size: 9.5, weight: .bold))
                            .tracking(1.6)
                            .foregroundStyle(Theme.accent)
                        Rectangle().fill(Theme.accent.opacity(0.35)).frame(width: 24, height: 1)
                        Text("NO WINDOWS REQUIRED")
                            .font(.system(size: 9.5, weight: .medium))
                            .tracking(1.2)
                            .foregroundStyle(Theme.secondary)
                    }
                    Text("Make it\nyours.")
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .lineSpacing(-4)
                    Text("20 lighting effects, per-key RGB, full key remapping, macro recording and a synced LCD clock. All from one place.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.secondary)
                        .lineSpacing(3)
                        .frame(maxWidth: 330, alignment: .leading)

                    HStack(spacing: 10) {
                        Button {
                            model.section = .lighting
                        } label: {
                            Label("Lighting", systemImage: "light.max")
                        }
                        .buttonStyle(AccentButtonStyle())

                        Button {
                            model.section = .perKey
                        } label: {
                            Label("Per-key studio", systemImage: "paintpalette")
                        }
                        .buttonStyle(GhostButtonStyle())
                    }
                    .padding(.top, 4)
                }
                .padding(.leading, 30)
                .padding(.vertical, 28)

                Spacer(minLength: 0)

                KeyboardView(
                    colorFor: { key in
                        let hue = 0.06 + (key.x / 22.5) * 0.58
                        return AulaRGB.hue(hue, saturation: 0.78, value: 1)
                    },
                    isInteractive: false
                )
                .frame(maxWidth: 610)
                .padding(.trailing, 24)
                .padding(.vertical, 26)
                .overlay(alignment: .center) {
                    RadialGradient(
                        colors: [Theme.accent.opacity(0.10), .clear],
                        center: .center, startRadius: 10, endRadius: 260
                    )
                    .allowsHitTesting(false)
                }
            }
            .background(
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: 0x181B21), Color(hex: 0x101216)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    RadialGradient(
                        colors: [Theme.accent.opacity(0.075), .clear],
                        center: .topLeading, startRadius: 20, endRadius: 520
                    )
                }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }

    private var quickBrightness: some View {
        Card(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Brightness", systemImage: "sun.max")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                    Spacer()
                    Text("\(model.state.lighting.brightness) / 5")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.text)
                }
                Slider(
                    value: Binding(
                        get: { Double(model.state.lighting.brightness) },
                        set: { model.state.lighting.brightness = UInt8($0) }
                    ),
                    in: 0...5, step: 1
                )
                .tint(Theme.accent)
                Button {
                    model.applyLighting()
                } label: {
                    Text("Send to keyboard")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .disabled(!model.canUseHardware && !model.isPreview)
                .opacity(model.canUseHardware || model.isPreview ? 1 : 0.4)
            }
        }
    }

    private var quickEffect: some View {
        Card(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Active effect", systemImage: "sparkles")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                    Spacer()
                    Circle()
                        .fill(Color(model.state.lighting.color))
                        .frame(width: 9, height: 9)
                        .shadow(color: Color(model.state.lighting.color).opacity(0.7), radius: 5)
                }
                Text(model.state.lighting.mode.name)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)
                Menu {
                    ForEach(LightingMode.allCases) { mode in
                        Button(mode.name) { model.setLightingMode(mode) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Change effect")
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }

    private var quickMacRemap: some View {
        Card(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Mac remap", systemImage: "command")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                    Spacer()
                    Circle()
                        .fill(model.remapRunning ? Theme.success : Theme.tertiary)
                        .frame(width: 7, height: 7)
                }
                Text(model.remapRunning ? "Active" : "Inactive")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)
                HStack(spacing: 8) {
                    Toggle("", isOn: Binding(
                        get: { model.state.macRemap.enabled },
                        set: { model.setMacRemapEnabled($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Theme.accent)

                    Button("Configure") { model.section = .macRemap }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    private var worksWhere: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("What works where")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Text("The keyboard has two independent control surfaces.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.secondary)
                    }
                    Spacer()
                    StatusPill(
                        text: model.connection.kind.supportsHardwareConfig ? "USB ready" : "USB needed",
                        color: model.connection.kind.supportsHardwareConfig ? Theme.success : Theme.accent,
                        icon: model.connection.kind.supportsHardwareConfig ? "checkmark" : "cable.connector"
                    )
                }

                HStack(alignment: .top, spacing: 0) {
                    capabilityColumn(
                        icon: "cable.connector",
                        title: "USB-C wired",
                        subtitle: "Full hardware control",
                        color: Theme.mint,
                        items: [
                            "20 backlight effects + color",
                            "Per-key RGB painting",
                            "Onboard key remap (normal + FN)",
                            "Macros stored on the keyboard",
                            "Sleep, debounce and key locks",
                            "LCD clock sync",
                        ],
                        available: true
                    )
                    Rectangle()
                        .fill(Theme.stroke)
                        .frame(width: 1)
                        .padding(.horizontal, 26)
                    capabilityColumn(
                        icon: "dot.radiowaves.left.and.right",
                        title: "Bluetooth",
                        subtitle: "Typing + macOS remap",
                        color: Theme.blue,
                        items: [
                            "Normal typing and media keys",
                            "Per-key macOS remapping",
                            "Macro playback on this Mac",
                            "Security: Secure Input still wins",
                        ],
                        available: model.connection.kind == .bluetooth,
                        note: "Hardware settings are not exposed over BLE — this is an AULA firmware limitation."
                    )
                }
            }
        }
    }

    private func capabilityColumn(
        icon: String, title: String, subtitle: String, color: Color,
        items: [String], available: Bool, note: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
                if available {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.success)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 7) {
                        Circle().fill(color.opacity(0.7)).frame(width: 4, height: 4).padding(.top, 5)
                        Text(item)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.secondary)
                    }
                }
            }
            if let note {
                Text(note)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.tertiary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fnCheatSheet: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Hardware shortcuts")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Text("FIRMWARE")
                        .font(.system(size: 8.5, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.tertiary)
                }
                shortcutRow("Fn + 4", "Switch to USB-C")
                shortcutRow("Fn + 1/2/3", "Bluetooth slot 1–3")
                shortcutRow("Fn + E", "macOS device mode")
                shortcutRow("Fn + L-Shift", "Light bar effect")
                shortcutRow("Fn + R-Shift", "Side strips effect")
                shortcutRow("Fn + /", "Side strip color")
            }
        }
    }

    private func shortcutRow(_ keys: String, _ action: String) -> some View {
        HStack {
            Text(keys)
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.06)))
            Spacer()
            Text(action)
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
        }
    }

    private var nextSteps: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Set up in three steps")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                stepRow(number: 1, title: "Connect USB-C", detail: "Settings travel over the wired config interface.", done: model.connection.kind == .wired)
                stepRow(number: 2, title: "Choose a look", detail: "Pick an effect or paint individual keys.", done: !model.state.perKey.isEmpty || model.state.lighting.mode != .rolling)
                stepRow(number: 3, title: "Make it Mac", detail: "Enable per-device remapping in Mac Remap.", done: model.state.macRemap.enabled)
                Spacer(minLength: 0)
                Text("Your settings are saved locally and can be re-applied at any time.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.tertiary)
            }
        }
    }

    private func stepRow(number: Int, title: String, detail: String, done: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(done ? Theme.success.opacity(0.16) : Color.white.opacity(0.06))
                    .frame(width: 22, height: 22)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.success)
                } else {
                    Text("\(number)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.text)
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.secondary)
            }
        }
    }
}
