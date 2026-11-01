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
        PageScroll {
            PageHeader(
                eyebrow: "Bluetooth or USB",
                title: "Mac remap",
                subtitle: "Per-key remapping in the macOS event layer. Works over Bluetooth; the keyboard firmware is not modified."
            ) {
                StatusPill(text: statusText, color: statusColor)
            }

            SplitRow {
                permissionsPanel
            } aside: {
                behaviorPanel
            }

            SplitRow {
                keyboardPanel
            } aside: {
                Card(fillHeight: true) {
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
            }

            limitationsPanel
        }
        .onAppear { model.refreshPermissions() }
    }

    // MARK: - Permissions

    /// What macOS has to allow, plus environment problems that stop remapping from working. Notes
    /// live here, in the wide column, so they read in two or three lines instead of eight.
    private var permissionsPanel: some View {
        Card(padding: 0, fillHeight: true) {
            VStack(alignment: .leading, spacing: 0) {
                // The refresh button is overlaid rather than passed as the band's accessory: as an
                // accessory it makes this band taller than Behavior's, and the rows beside each
                // other stop lining up.
                PanelHeaderBand("Permissions", detail: "Granted per app in System Settings → Privacy & Security.")
                    .overlay(alignment: .trailing) {
                        Button {
                            model.refreshPermissions()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(GhostButtonStyle())
                        .help("Refresh permission status")
                        .accessibilityLabel("Refresh permission status")
                        .padding(.trailing, Theme.panelInset)
                        .padding(.bottom, 1)
                    }

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
                .frame(maxHeight: hasNotes ? nil : .infinity)

                if hasNotes {
                    Hairline()
                    VStack(alignment: .leading, spacing: 8) {
                        if !model.accessibilityGranted {
                            InlineNote(
                                text: "macOS may ask you to relaunch after granting Accessibility. Remapping turns on automatically once the permission is detected.",
                                tint: Theme.blue,
                                icon: "info.circle"
                            )
                        }
                        if let error = model.remapError {
                            InlineNote(text: error, tint: Theme.danger, icon: "xmark.octagon")
                        }
                        if model.karabinerPresent {
                            InlineNote(
                                text: "Karabiner-Elements is running and may hide the F108 Pro behind its virtual keyboard. Turn off Modify events for the AULA in Karabiner → Devices, or Only the AULA keyboard here.",
                                tint: Theme.accent,
                                icon: "exclamationmark.triangle"
                            )
                        }
                    }
                    .padding(Theme.panelInset)
                }
            }
        }
    }

    private var hasNotes: Bool {
        !model.accessibilityGranted || model.remapError != nil || model.karabinerPresent
    }

    private func permissionRow(
        title: String, detail: String,
        granted: Bool, action: @escaping () -> Void
    ) -> some View {
        FormRow(title, detail: detail) {
            if granted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.success)
                    Text("Granted")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.secondary)
                }
            } else {
                Button("Grant") { action() }
                    .buttonStyle(GhostButtonStyle())
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title), \(granted ? "granted" : "not granted")")
    }

    // MARK: - Behavior

    private var behaviorPanel: some View {
        Card(padding: 0, fillHeight: true) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeaderBand("Behavior", detail: "Applies while AULA Control is running.")

                FormRow("Enable macOS remapping", detail: "Rewrites keys in the event layer.") {
                    switchControl(isOn: Binding(
                        get: { model.state.macRemap.enabled },
                        set: { model.setMacRemapEnabled($0) }
                    ))
                }
                Hairline()
                FormRow("Only the AULA keyboard", detail: "Leaves the built-in keyboard untouched.") {
                    switchControl(isOn: Binding(
                        get: { model.state.macRemap.onlyThisKeyboard },
                        set: { model.state.macRemap.onlyThisKeyboard = $0 }
                    ))
                }
                .disabled(!model.state.macRemap.enabled)
                .opacity(model.state.macRemap.enabled ? 1 : 0.45)
                Hairline()
                // The two columns hold different row counts; the last row takes up the difference
                // so neither panel ends in an empty strip.
                lastKeySourceRow
                    .frame(maxHeight: .infinity)
            }
        }
    }

    private func switchControl(isOn: Binding<Bool>) -> some View {
        Toggle("", isOn: isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(Theme.accent)
    }

    /// Diagnostic readout: shows which HID device macOS attributed the last key event to, so the
    /// "Only the AULA keyboard" filter can be verified.
    private var lastKeySourceRow: some View {
        FormRow("Last key source", detail: "Device that sent the last key.") {
            if let source = model.lastKeySource {
                HStack(spacing: 6) {
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
                }
                .frame(maxWidth: 150, alignment: .trailing)
            } else {
                Text("Press a key")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.tertiary)
            }
        }
    }

    // MARK: - Key map

    private var keyboardPanel: some View {
        Card(padding: 0, fillHeight: true) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeaderBand("Key map", detail: "Click a key to remap it. Changes apply immediately; there is no Apply step.") {
                    HStack(spacing: 8) {
                        if !map.isEmpty {
                            ValueChip("\(map.count) mapped")
                        }
                        Button {
                            model.clearMacRemap()
                        } label: {
                            Text("Clear")
                        }
                        .buttonStyle(GhostButtonStyle())
                        .disabled(map.isEmpty)
                        .help("Remove every macOS remap")
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
                .padding(Theme.panelInset)

                Hairline()

                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(Theme.accent)
                            .frame(width: 5, height: 5)
                            .frame(width: 10, height: 10)
                        Text("Remapped in macOS")
                    }
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(Theme.accent, lineWidth: 1.5)
                            .frame(width: 10, height: 10)
                        Text("Selected")
                    }
                    Spacer(minLength: 12)
                    Text(model.state.macRemap.enabled ? "Active while the app runs." : "Remapping is off.")
                        .foregroundStyle(Theme.tertiary)
                }
                .font(Theme.captionFont)
                .foregroundStyle(Theme.secondary)
                .frame(minHeight: Theme.rowHeight)
                .padding(.horizontal, Theme.panelInset)

                Hairline()

                MappingList(
                    title: "Remapped keys",
                    keys: KeyLayout.f108Pro.keys.filter { map[$0.name] != nil },
                    map: map,
                    selectedKey: selectedKey?.name
                ) { model.selectedKey = $0 }
                .padding(Theme.panelInset)

                // Presets sit on the panel's bottom edge so they line up with the inspector's
                // footer in the column beside it.
                Spacer(minLength: 0)
                Hairline()
                FormRow("Presets", detail: "Mac modifiers swaps Alt/Win for Option/Command so the bottom row matches an Apple keyboard.") {
                    HStack(spacing: 8) {
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
                    }
                    .fixedSize()
                }
            }
        }
    }

    // MARK: - Limitations

    private var limitationsPanel: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeaderBand("How it behaves")
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
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.text)
            Text(text)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.secondary)
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.panelInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
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
