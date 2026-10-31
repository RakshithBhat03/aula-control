import SwiftUI
import AulaKit

struct MacRemapView: View {
    @EnvironmentObject var model: AppModel

    private var map: KeyRemapMap { model.state.macRemap.map }

    private var selectedKey: KeyCap? {
        model.selectedKey.flatMap { KeyLayout.f108Pro.key(named: $0) } ?? KeyLayout.f108Pro.key(named: "capslock")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    eyebrow: "MACOS · BLUETOOTH OR USB",
                    title: "Mac remap",
                    subtitle: "Per-key remapping at the macOS event layer. This is the part that works over Bluetooth — the keyboard's firmware is never touched."
                ) {
                    StatusPill(
                        text: model.remapRunning ? "Remapping active" : (model.state.macRemap.enabled ? "Waiting for permission" : "Off"),
                        color: model.remapRunning ? Theme.success : (model.state.macRemap.enabled ? Theme.accent : Theme.tertiary),
                        icon: model.remapRunning ? "bolt.fill" : "command"
                    )
                }

                HStack(alignment: .top, spacing: 18) {
                    permissionCard
                    behaviorCard
                }

                HStack(alignment: .top, spacing: 18) {
                    Card(padding: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Click a key to remap it")
                                    .font(.system(size: 11.5, weight: .medium))
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
                                    return AulaRGB(40, 52, 44)
                                },
                                selectedKey: selectedKey?.name,
                                mappedKeys: Set(map.keys),
                                showRemapDot: true,
                                onTap: { key in model.selectedKey = key.name }
                            )
                            .padding(.horizontal, 4)
                            .opacity(model.state.macRemap.enabled ? 1 : 0.72)

                            HStack(spacing: 16) {
                                HStack(spacing: 5) {
                                    Circle().fill(Theme.mint).frame(width: 5, height: 5)
                                    Text("Remapped in macOS").font(.system(size: 10)).foregroundStyle(Theme.tertiary)
                                }
                                Spacer()
                                Text("Send a key to this Mac to test it — no Apply needed.")
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
                                    model.setMacRemap(key.name, action: action)
                                }
                            )
                            .id("mac-\(key.name)")
                        } else {
                            EmptyState(icon: "command", title: "Select a key", message: "Click a key on the board to set its macOS behavior.")
                        }
                    }
                    .frame(width: 330)
                }

                limitationsCard
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
        .onAppear { model.refreshPermissions() }
    }

    private var permissionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Permissions")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Button {
                        model.refreshPermissions()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(GhostButtonStyle())
                    .help("Refresh permission status")
                }

                permissionRow(
                    icon: "lock.shield",
                    title: "Accessibility",
                    detail: "Required to intercept and rewrite key events.",
                    granted: model.accessibilityGranted
                ) {
                    model.requestAccessibility()
                }

                permissionRow(
                    icon: "keyboard.badge.ellipsis",
                    title: "Input Monitoring",
                    detail: "Lets the app identify the AULA keyboard among HID devices.",
                    granted: model.inputMonitoringGranted
                ) {
                    model.requestInputMonitoring()
                }

                if !model.accessibilityGranted {
                    Text("After granting Accessibility, macOS may ask you to relaunch the app. The toggle turns on automatically once permission is detected.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.tertiary)
                        .lineSpacing(1.5)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func permissionRow(
        icon: String, title: String, detail: String,
        granted: Bool, action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(granted ? Theme.success : Theme.accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(granted ? Theme.success : Theme.accent)
                }
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if !granted {
                Button("Grant") { action() }
                    .buttonStyle(GhostButtonStyle())
            }
        }
    }

    private var behaviorCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Behavior")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Circle()
                        .fill(model.remapRunning ? Theme.success : Theme.tertiary)
                        .frame(width: 7, height: 7)
                }

                ToggleRow(
                    title: "Enable macOS remapping",
                    subtitle: "Intercept keys only while this app is running",
                    isOn: Binding(
                        get: { model.state.macRemap.enabled },
                        set: { model.setMacRemapEnabled($0) }
                    )
                )

                ToggleRow(
                    title: "Only the AULA keyboard",
                    subtitle: "Leave the MacBook keyboard untouched",
                    isOn: Binding(
                        get: { model.state.macRemap.onlyThisKeyboard },
                        set: { model.state.macRemap.onlyThisKeyboard = $0 }
                    )
                )
                .disabled(!model.state.macRemap.enabled)
                .opacity(model.state.macRemap.enabled ? 1 : 0.45)

                if let error = model.remapError {
                    Text(error)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.danger)
                        .lineSpacing(1.5)
                }

                HStack(spacing: 8) {
                    Circle()
                        .fill(model.lastKeySource?.localizedCaseInsensitiveContains("aula") == true ? Theme.success : Theme.tertiary)
                        .frame(width: 6, height: 6)
                    Text("Last key source")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.secondary)
                    Spacer()
                    Text(model.lastKeySource ?? "Press a key to test")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(model.lastKeySource == nil ? Theme.tertiary : Theme.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(9)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.025)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.stroke, lineWidth: 1))

                if model.karabinerPresent {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                        Text("Karabiner-Elements is running. If it grabs the F108 Pro, macOS reports Karabiner's virtual keyboard instead of the physical device. Turn off “Modify events” for the AULA in Karabiner → Devices, or switch off “Only the AULA keyboard” here.")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.accent.opacity(0.85))
                            .lineSpacing(1.5)
                    }
                    .padding(9)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.accent.opacity(0.16), lineWidth: 1))
                }

                Rectangle().fill(Theme.stroke).frame(height: 1)

                Text("Presets")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.secondary)

                HStack(spacing: 8) {
                    Button {
                        model.applyMacPreset()
                    } label: {
                        Text("Mac modifiers")
                    }
                    .buttonStyle(GhostButtonStyle())

                    Button {
                        model.state.macRemap.map = RemapPresets.capsToControl
                    } label: {
                        Text("Caps → Control")
                    }
                    .buttonStyle(GhostButtonStyle())

                    Button {
                        model.clearMacRemap()
                    } label: {
                        Text("Clear")
                    }
                    .buttonStyle(GhostButtonStyle())
                }

                Text("The preset swaps Alt/Win for Option/Command so the bottom row feels like an Apple keyboard.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.tertiary)
                    .lineSpacing(1.5)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var limitationsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Theme.accent)
                    Text("How it behaves")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                }
                HStack(alignment: .top, spacing: 24) {
                    limitation("Works over Bluetooth", "The event tap runs in macOS, so it does not need the vendor HID interface.")
                    limitation("Per-device", "Uses the HID sender identity, so your MacBook keyboard and other keyboards keep their normal behavior.")
                    limitation("Secure Input wins", "Password fields and some apps block event taps by design. Remaps pause there.")
                    limitation("No kernel extension", "Accessibility permission only — nothing is installed into the system.")
                }
            }
        }
    }

    private func limitation(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text(text)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.secondary)
                .lineSpacing(1.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
