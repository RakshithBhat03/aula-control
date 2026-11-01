import SwiftUI
import AulaKit

struct SettingsView: View {
    @EnvironmentObject var model: AppModel

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    eyebrow: "macOS",
                    title: "Settings",
                    subtitle: "Startup behavior, permissions and the local configuration file."
                )

                VStack(alignment: .leading, spacing: 16) {
                    generalGroup
                    permissionsGroup
                    configurationGroup
                    aboutGroup
                }
                .frame(maxWidth: 720, alignment: .leading)
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Groups

    private var generalGroup: some View {
        SettingsGroup(title: "General") {
            FormCell {
                ToggleRow(
                    title: "Launch at login",
                    subtitle: "Keeps remapping active after a restart.",
                    isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
            }
            Hairline()
            FormCell {
                ToggleRow(
                    title: "Apply saved config on USB connect",
                    subtitle: "Sends lighting, keymap and macros when the cable is plugged in.",
                    isOn: Binding(
                        get: { model.state.autoApplyOnConnect },
                        set: { model.state.autoApplyOnConnect = $0 }
                    )
                )
            }
            Hairline()
            FormCell {
                ToggleRow(
                    title: "Preview mode",
                    subtitle: "Simulates every command without writing to the keyboard. Use it to try layouts before plugging in.",
                    isOn: Binding(
                        get: { model.demoMode },
                        set: { model.demoMode = $0 }
                    )
                )
            }
        }
    }

    private var permissionsGroup: some View {
        SettingsGroup(
            title: "Permissions",
            detail: "Granted in System Settings > Privacy & Security."
        ) {
            Button {
                model.refreshPermissions()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(GhostButtonStyle())
            .help("Re-check permission status")
        } content: {
            permission("Accessibility", "Remap keys and play macros.", model.accessibilityGranted) {
                model.requestAccessibility()
            }
            Hairline()
            permission("Input Monitoring", "Identify the keyboard's HID services.", model.inputMonitoringGranted) {
                model.requestInputMonitoring()
            }
        }
    }

    private var configurationGroup: some View {
        SettingsGroup(
            title: "Configuration file",
            detail: "Saved automatically. The keyboard protocol is write-only, so this file is the source of truth."
        ) {
            ValueChip("JSON", color: Theme.secondary)
        } content: {
            FormCell {
                HStack(spacing: 10) {
                    Text(model.store.url.path)
                        .font(Theme.monoFont)
                        .foregroundStyle(Theme.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                                .fill(Theme.field)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                                .strokeBorder(Theme.stroke, lineWidth: 1)
                        )

                    Button {
                        model.revealStateFile()
                    } label: {
                        Label("Reveal in Finder", systemImage: "folder")
                    }
                    .buttonStyle(GhostButtonStyle())
                }
            }
        }
    }

    private var aboutGroup: some View {
        SettingsGroup(
            title: "About",
            detail: "Not affiliated with AULA. Use at your own risk; firmware updates can change the protocol."
        ) {
            FormCell {
                SpecRow(label: "Version") { ValueChip(appVersion) }
            }
            Hairline()
            FormCell {
                SpecRow(label: "Device") { ValueChip("AULA F108 Pro") }
            }
            Hairline()
            FormCell {
                SpecRow(label: "Interface") { ValueChip("USB HID 0xFF13") }
            }
            Hairline()
            FormCell {
                SpecRow(label: "Driver") {
                    Text("None, no kernel extension")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.secondary)
                }
            }
            Hairline()
            FormCell {
                SpecRow(label: "Storage") {
                    Text("Settings stay on this Mac")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.secondary)
                }
            }
            Hairline()
            VStack(alignment: .leading, spacing: 0) {
                Text("Protocol sources")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                SourceLink(repo: "parsiya/f108-pro")
                SourceLink(repo: "bacoinz/aula-studio")
                SourceLink(repo: "sarequl/aula-studio")
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: - Rows

    private func permission(_ title: String, _ detail: String, _ granted: Bool, action: @escaping () -> Void) -> some View {
        FormCell {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Text(detail)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
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

// MARK: - Form primitives

/// One flat panel per settings section: header strip, hairline, then rows separated by hairlines.
private struct SettingsGroup<Trailing: View, Content: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content

    init(
        title: String,
        detail: String? = nil,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.detail = detail
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeader(title, detail: detail) { trailing }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                Hairline()
                content
            }
        }
    }
}

extension SettingsGroup where Trailing == EmptyView {
    init(title: String, detail: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, detail: detail, trailing: { EmptyView() }, content: content)
    }
}

private struct FormCell<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Hairline: View {
    var body: some View {
        Rectangle().fill(Theme.stroke).frame(height: 1)
    }
}

/// Label on the left, read-only value on the right, like a spec sheet line.
private struct SpecRow<Value: View>: View {
    let label: String
    @ViewBuilder var value: Value

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.text)
            Spacer()
            value
        }
    }
}

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
                    Spacer()
                    Text("github.com")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.tertiary)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.tertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                        .fill(hovering ? Theme.cardRaised : Color.clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .onHover { hovering = $0 }
            .help(url.absoluteString)
        }
    }
}
