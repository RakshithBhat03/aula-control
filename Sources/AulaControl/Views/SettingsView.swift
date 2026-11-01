import SwiftUI
import AulaKit

struct SettingsView: View {
    @EnvironmentObject var model: AppModel

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        PageScroll {
            PageHeader(
                eyebrow: "macOS",
                title: "Settings",
                subtitle: "Startup behavior, permissions and the local configuration file."
            )

            SplitRow {
                VStack(alignment: .leading, spacing: Theme.gutter) {
                    generalPanel
                    permissionsPanel
                    configurationPanel
                }
            } aside: {
                aboutPanel
            }
        }
    }

    // MARK: - Panels

    private var generalPanel: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeaderBand("General", detail: "Startup and preview behavior.")
                FormRow("Launch at login", detail: "Keeps remapping active after a restart.") {
                    SettingsSwitch(label: "Launch at login", isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    ))
                }
                Hairline()
                FormRow(
                    "Apply saved config on USB connect",
                    detail: "Sends lighting, keymap and macros when the cable is plugged in."
                ) {
                    SettingsSwitch(label: "Apply saved config on USB connect", isOn: Binding(
                        get: { model.state.autoApplyOnConnect },
                        set: { model.state.autoApplyOnConnect = $0 }
                    ))
                }
                Hairline()
                FormRow(
                    "Preview mode",
                    detail: "Simulates every command without writing to the keyboard. Use it to try layouts before plugging in."
                ) {
                    SettingsSwitch(label: "Preview mode", isOn: Binding(
                        get: { model.demoMode },
                        set: { model.demoMode = $0 }
                    ))
                }
            }
        }
    }

    private var permissionsPanel: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeaderBand("Permissions", detail: "Granted in System Settings > Privacy & Security.") {
                    Button {
                        model.refreshPermissions()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(GhostButtonStyle())
                    .help("Re-check permission status")
                }
                permission("Accessibility", "Remap keys and play macros.", model.accessibilityGranted) {
                    model.requestAccessibility()
                }
                Hairline()
                permission("Input Monitoring", "Identify the keyboard's HID services.", model.inputMonitoringGranted) {
                    model.requestInputMonitoring()
                }
            }
        }
    }

    private var configurationPanel: some View {
        Card(padding: 0, fillHeight: true) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeaderBand(
                    "Configuration file",
                    detail: "Saved automatically. The keyboard protocol is write-only, so this file is the source of truth."
                ) {
                    ValueChip("JSON", color: Theme.secondary)
                }
                HStack(spacing: 10) {
                    Text((model.store.url.path as NSString).abbreviatingWithTildeInPath)
                        .font(Theme.monoFont)
                        .foregroundStyle(Theme.secondary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                                .fill(Theme.field)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                                .strokeBorder(Theme.stroke, lineWidth: 1)
                        )
                        .help(model.store.url.path)

                    Button {
                        model.revealStateFile()
                    } label: {
                        Label("Reveal in Finder", systemImage: "folder")
                    }
                    .buttonStyle(GhostButtonStyle())
                }
                .padding(Theme.panelInset)
            }
        }
    }

    private var aboutPanel: some View {
        Card(padding: 0, fillHeight: true) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeaderBand(
                    "About",
                    detail: "Not affiliated with AULA."
                )
                FormRow("Version") { ValueChip(appVersion) }
                Hairline()
                FormRow("Device") { RowValueText("AULA F108 Pro") }
                Hairline()
                FormRow("Interface") { ValueChip("USB HID 0xFF13") }
                Hairline()
                FormRow("Driver") { RowValueText("None, no kernel extension") }
                Hairline()
                FormRow("Storage") { RowValueText("Settings stay on this Mac") }
                Hairline()

                // When the aside is stretched to the main column, the slack sits above the sources
                // group as section spacing instead of as a void under the last link.
                Spacer(minLength: 0)

                Text("Protocol sources")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.tertiary)
                    .padding(.horizontal, Theme.panelInset)
                    .padding(.top, 12)
                    .padding(.bottom, 2)
                SourceLink(repo: "parsiya/f108-pro")
                Hairline()
                SourceLink(repo: "bacoinz/aula-studio")
                Hairline()
                SourceLink(repo: "sarequl/aula-studio")
            }
        }
    }

    // MARK: - Rows

    private func permission(_ title: String, _ detail: String, _ granted: Bool, action: @escaping () -> Void) -> some View {
        FormRow(title, detail: detail) {
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(granted ? Theme.success : Theme.danger)
                        .frame(width: 6, height: 6)
                    Text(granted ? "Granted" : "Not granted")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.secondary)
                }
                .accessibilityElement(children: .combine)
                if !granted {
                    Button("Grant") { action() }
                        .buttonStyle(GhostButtonStyle())
                }
            }
        }
    }
}

// MARK: - Row pieces

private struct SettingsSwitch: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(label, isOn: $isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(Theme.accent)
    }
}

/// Plain-language read-only value at a row's trailing edge.
private struct RowValueText: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Theme.captionFont)
            .foregroundStyle(Theme.secondary)
            .lineLimit(1)
    }
}

/// A repository link as a full-width row, on the same height and insets as `FormRow`.
private struct SourceLink: View {
    let repo: String
    @State private var hovering = false

    private var url: URL? { URL(string: "https://github.com/\(repo)") }

    var body: some View {
        if let url {
            Link(destination: url) {
                HStack(spacing: 8) {
                    Text(repo)
                        .font(Theme.monoFont)
                        .foregroundStyle(hovering ? Theme.text : Theme.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("github.com")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.tertiary)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.tertiary)
                }
                .frame(minHeight: Theme.rowHeight)
                .padding(.horizontal, Theme.panelInset)
                .padding(.vertical, 6)
                .background(hovering ? Theme.cardRaised : Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .help(url.absoluteString)
        }
    }
}
