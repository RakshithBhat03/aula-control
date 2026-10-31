import SwiftUI
import AulaKit

struct SettingsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    eyebrow: "AULA CONTROL",
                    title: "Settings",
                    subtitle: "Startup behavior, permissions and the local configuration file."
                )

                HStack(alignment: .top, spacing: 18) {
                    Card {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("App")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.text)

                            ToggleRow(
                                title: "Launch at login",
                                subtitle: "Keep remapping active after a restart",
                                isOn: Binding(
                                    get: { model.launchAtLogin },
                                    set: { model.setLaunchAtLogin($0) }
                                )
                            )

                            ToggleRow(
                                title: "Apply saved config on USB connect",
                                subtitle: "Push lighting, keymap and macros when the cable appears",
                                isOn: Binding(
                                    get: { model.state.autoApplyOnConnect },
                                    set: { model.state.autoApplyOnConnect = $0 }
                                )
                            )

                            ToggleRow(
                                title: "Preview mode",
                                subtitle: "Explore the UI without writing to hardware",
                                isOn: Binding(
                                    get: { model.demoMode },
                                    set: { model.demoMode = $0 }
                                )
                            )

                            Text("Preview mode simulates every command. It is useful for trying layouts before you plug in the keyboard.")
                                .font(.system(size: 10.5))
                                .foregroundStyle(Theme.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Card {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Permissions")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.text)

                            permission("Accessibility", "Remap keys and play macros", model.accessibilityGranted) {
                                model.requestAccessibility()
                            }
                            permission("Input Monitoring", "Identify the keyboard's HID services", model.inputMonitoringGranted) {
                                model.requestInputMonitoring()
                            }

                            Button {
                                model.refreshPermissions()
                            } label: {
                                Label("Refresh status", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(GhostButtonStyle())
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                Card {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack {
                            Text("Configuration file")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Spacer()
                            Text("JSON")
                                .font(.system(size: 8.5, weight: .bold))
                                .tracking(1.1)
                                .foregroundStyle(Theme.tertiary)
                        }
                        Text(model.store.url.path)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(Theme.secondary)
                            .textSelection(.enabled)
                            .lineLimit(2)
                        HStack(spacing: 10) {
                            Button {
                                model.revealStateFile()
                            } label: {
                                Label("Reveal in Finder", systemImage: "folder")
                            }
                            .buttonStyle(GhostButtonStyle())

                            Text("Settings save automatically. The file is the source of truth because the keyboard protocol is write-only.")
                                .font(.system(size: 10.5))
                                .foregroundStyle(Theme.tertiary)
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        HStack(alignment: .top, spacing: 28) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("AULA Control 1.0.0")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Theme.text)
                                Text("A native macOS companion for the AULA F108 Pro. Not affiliated with AULA. Use at your own risk; the protocol can change with firmware updates.")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(Theme.secondary)
                                    .lineSpacing(1.5)
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 6) {
                                Eyebrow(text: "PROTOCOL SOURCES")
                                Link("parsiya/f108-pro", destination: URL(string: "https://github.com/parsiya/f108-pro")!)
                                Link("bacoinz/aula-studio", destination: URL(string: "https://github.com/bacoinz/aula-studio")!)
                                Link("sarequl/aula-studio", destination: URL(string: "https://github.com/sarequl/aula-studio")!)
                            }
                            .font(.system(size: 10.5))
                            .tint(Theme.accent)
                        }

                        Rectangle().fill(Theme.stroke).frame(height: 1)

                        HStack(spacing: 18) {
                            Label("USB HID 0xFF13", systemImage: "cable.connector")
                            Label("No kernel extension", systemImage: "checkmark.shield")
                            Label("Settings stay on-device", systemImage: "internaldrive")
                            Spacer()
                            Text("F108 PRO")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(Theme.tertiary)
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.tertiary)
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
    }

    private func permission(_ title: String, _ detail: String, _ granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(granted ? Theme.success : Theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.text)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.secondary)
            }
            Spacer()
            if !granted {
                Button("Grant") { action() }
                    .buttonStyle(GhostButtonStyle())
            }
        }
    }
}
