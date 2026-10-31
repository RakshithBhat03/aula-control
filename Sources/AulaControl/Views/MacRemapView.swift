import SwiftUI
import AulaKit

struct MacRemapView: View {
    @EnvironmentObject var model: AppModel

    private var map: KeyRemapMap { model.state.macRemap.map }

    private var selectedKey: KeyCap? {
        model.selectedKey.flatMap { KeyLayout.f108Pro.key(named: $0) } ?? KeyLayout.f108Pro.key(named: "capslock")
    }

    /// Face tint for remapped caps: a warm graphite that reads as "changed" without competing with
    /// the accent selection ring.
    private static let mappedKeyTint = AulaRGB(46, 41, 32)

    private var statusText: String {
        if model.remapRunning { return "Remapping active" }
        return model.state.macRemap.enabled ? "Waiting for permission" : "Off"
    }

    private var statusColor: Color {
        if model.remapRunning { return Theme.success }
        return model.state.macRemap.enabled ? Theme.accent : Theme.tertiary
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    eyebrow: "Bluetooth or USB",
                    title: "Mac remap",
                    subtitle: "Per-key remapping in the macOS event layer. Works over Bluetooth; the keyboard firmware is not modified."
                ) {
                    StatusPill(text: statusText, color: statusColor)
                }

                setupPanel

                HStack(alignment: .top, spacing: 16) {
                    keyboardPanel

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

                limitationsPanel
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .onAppear { model.refreshPermissions() }
    }

    // MARK: - Setup: permissions and behavior

    private var setupPanel: some View {
        Card(padding: 0) {
            HStack(alignment: .top, spacing: 0) {
                permissionColumn
                    .padding(18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Hairline(axis: .vertical)
                behaviorColumn
                    .padding(18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var permissionColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader("Permissions", detail: "Granted per app in System Settings → Privacy & Security.") {
                Button {
                    model.refreshPermissions()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(GhostButtonStyle())
                .help("Refresh permission status")
                .accessibilityLabel("Refresh permission status")
            }
            .padding(.bottom, 12)

            Hairline()
            permissionRow(
                title: "Accessibility",
                detail: "Required to intercept and rewrite key events.",
                granted: model.accessibilityGranted
            ) {
                model.requestAccessibility()
            }
            Hairline()
            permissionRow(
                title: "Input Monitoring",
                detail: "Identifies the AULA keyboard among HID devices.",
                granted: model.inputMonitoringGranted
            ) {
                model.requestInputMonitoring()
            }
            Hairline()

            if !model.accessibilityGranted {
                Text("macOS may ask you to relaunch after granting Accessibility. The toggle turns on automatically once the permission is detected.")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.tertiary)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }
        }
    }

    private func permissionRow(
        title: String, detail: String,
        granted: Bool, action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(granted ? Theme.success : Theme.tertiary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.text)
                Text(detail)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if granted {
                Text("Granted")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.secondary)
            } else {
                Button("Grant") { action() }
                    .buttonStyle(GhostButtonStyle())
            }
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title), \(granted ? "granted" : "not granted")")
    }

    private var behaviorColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader("Behavior") {
                Circle()
                    .fill(model.remapRunning ? Theme.success : Theme.tertiary)
                    .frame(width: 6, height: 6)
                    .help(model.remapRunning ? "Event tap running" : "Event tap stopped")
            }
            .padding(.bottom, 12)

            Hairline()
            ToggleRow(
                title: "Enable macOS remapping",
                subtitle: "Intercepts keys only while this app is running.",
                isOn: Binding(
                    get: { model.state.macRemap.enabled },
                    set: { model.setMacRemapEnabled($0) }
                )
            )
            .padding(.vertical, 11)
            Hairline()
            ToggleRow(
                title: "Only the AULA keyboard",
                subtitle: "Leaves the built-in keyboard untouched.",
                isOn: Binding(
                    get: { model.state.macRemap.onlyThisKeyboard },
                    set: { model.state.macRemap.onlyThisKeyboard = $0 }
                )
            )
            .disabled(!model.state.macRemap.enabled)
            .opacity(model.state.macRemap.enabled ? 1 : 0.45)
            .padding(.vertical, 11)
            Hairline()

            lastKeySourceRow
                .padding(.vertical, 11)

            if let error = model.remapError {
                InlineNote(text: error, tint: Theme.danger, icon: "xmark.octagon")
                    .padding(.top, 4)
            }

            if model.karabinerPresent {
                InlineNote(
                    text: "Karabiner-Elements is running. If it grabs the F108 Pro, macOS reports Karabiner's virtual keyboard instead of the device. Turn off Modify events for the AULA in Karabiner → Devices, or turn off Only the AULA keyboard here.",
                    tint: Theme.accent,
                    icon: "exclamationmark.triangle"
                )
                .padding(.top, 4)
            }
        }
    }

    /// Diagnostic readout: shows which HID device macOS attributed the last key event to, so the
    /// "Only the AULA keyboard" filter can be verified.
    private var lastKeySourceRow: some View {
        HStack(spacing: 10) {
            Text("Last key source")
                .font(.system(size: 12.5, weight: .medium))
                .fixedSize()
                .foregroundStyle(Theme.text)
            Spacer(minLength: 8)
            if let source = model.lastKeySource {
                Circle()
                    .fill(source.localizedCaseInsensitiveContains("aula") ? Theme.success : Theme.tertiary)
                    .frame(width: 6, height: 6)
                // Not a ValueChip: device names can be long and must truncate in the middle.
                Text(source)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Theme.field))
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
            } else {
                Text("Press a key to test")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.tertiary)
            }
        }
    }

    // MARK: - Key map

    private var keyboardPanel: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                PanelHeader("Key map", detail: "Click a key to remap it. Changes apply immediately; there is no Apply step.") {
                    if !map.isEmpty {
                        ValueChip("\(map.count) mapped")
                    }
                }

                KeyboardView(
                    colorFor: { key in
                        guard map[key.name] != nil else { return nil }
                        return Self.mappedKeyTint
                    },
                    selectedKey: selectedKey?.name,
                    mappedKeys: Set(map.keys),
                    showRemapDot: true,
                    onTap: { key in model.selectedKey = key.name }
                )
                .opacity(model.state.macRemap.enabled ? 1 : 0.72)

                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(Theme.accent)
                        .frame(width: 5, height: 5)
                    Text("Remapped in macOS")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.tertiary)
                }

                Hairline()

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Presets")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.secondary)
                            .frame(width: 56, alignment: .leading)

                        Button {
                            model.applyMacPreset()
                        } label: {
                            Text("Mac modifiers")
                        }
                        .buttonStyle(GhostButtonStyle())
                        .help("Swap Alt/Win for Option/Command")

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

                        Spacer(minLength: 0)
                    }

                    Text("Mac modifiers swaps Alt/Win for Option/Command so the bottom row matches an Apple keyboard.")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.tertiary)
                        .padding(.leading, 64)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Limitations

    private var limitationsPanel: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeader("How it behaves")
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                Hairline()
                HStack(alignment: .top, spacing: 0) {
                    limitation("Works over Bluetooth", "The event tap runs in macOS, so the vendor HID interface is not needed.")
                    Hairline(axis: .vertical)
                    limitation("Per device", "Matches the HID sender, so the built-in keyboard and other keyboards keep their behavior.")
                    Hairline(axis: .vertical)
                    limitation("Secure Input", "Password fields and some apps block event taps by design. Remaps pause there.")
                    Hairline(axis: .vertical)
                    limitation("No kernel extension", "Needs Accessibility permission only. Nothing is installed into the system.")
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func limitation(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text)
            Text(text)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.secondary)
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// One-pixel separator used between rows and columns inside a single panel, so the page keeps one
/// level of cards.
private struct Hairline: View {
    var axis: Axis = .horizontal

    var body: some View {
        switch axis {
        case .horizontal:
            Rectangle().fill(Theme.stroke).frame(height: 1).frame(maxWidth: .infinity)
        case .vertical:
            Rectangle().fill(Theme.stroke).frame(width: 1).frame(maxHeight: .infinity)
        }
    }
}

/// Flat inline note: a thin status bar on the leading edge over the field surface. Used for
/// warnings and errors that belong to a panel rather than the whole page.
private struct InlineNote: View {
    let text: String
    let tint: Color
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint)
                .padding(.top, 1)
            Text(text)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.secondary)
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                .fill(Theme.field)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(tint)
                .frame(width: 2)
                .padding(.vertical, 6)
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }
}
