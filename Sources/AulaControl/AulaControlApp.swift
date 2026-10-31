import SwiftUI
import AulaKit

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
            Rectangle()
                .fill(Theme.stroke)
                .frame(width: 1)
            content
        }
        .background(Theme.background)
        .overlay(alignment: .bottomTrailing) {
            if let toast = model.toast {
                Toast(
                    kind: toast.kind == .success ? .success : (toast.kind == .error ? .error : .info),
                    message: toast.text
                )
                .padding(24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(toast.id)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.toast?.id)
        .frame(minWidth: 1120, minHeight: 720)
        .background(WindowConfigurator())
    }

    @ViewBuilder
    private var content: some View {
        switch model.section {
        case .overview:
            OverviewView()
        case .lighting:
            LightingView()
        case .perKey:
            PerKeyView()
        case .keymap:
            KeymapView()
        case .macros:
            MacrosView()
        case .device:
            DeviceView()
        case .macRemap:
            MacRemapView()
        case .settings:
            SettingsView()
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var model: AppModel

    private var grouped: [(String, [AppSection])] {
        let order: [AppSection] = [.overview, .lighting, .perKey, .keymap, .macros, .device, .macRemap, .settings]
        var groups: [(String, [AppSection])] = []
        for section in order {
            if let index = groups.firstIndex(where: { $0.0 == section.group }) {
                groups[index].1.append(section)
            } else {
                groups.append((section.group, [section]))
            }
        }
        return groups
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
                .padding(.horizontal, 20)
                .padding(.top, 42)
                .padding(.bottom, 26)

            VStack(alignment: .leading, spacing: 22) {
                ForEach(grouped, id: \.0) { group, sections in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(group)
                            .font(.system(size: 9.5, weight: .semibold))
                            .tracking(1.8)
                            .foregroundStyle(Theme.tertiary)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 3)
                        ForEach(sections) { section in
                            sidebarButton(section)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 20)

            ConnectionCard()
                .padding(.horizontal, 14)
                .padding(.bottom, 14)

            HStack {
                Text("v1.0.0")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.tertiary)
                Spacer()
                Text("F108 PRO")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 232)
        .background(
            LinearGradient(
                colors: [Theme.sidebar, Color(hex: 0x0B0D10)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    private var brand: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Theme.accent, Theme.accentDeep],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x1A1408))
            }
            .frame(width: 34, height: 34)
            .shadow(color: Theme.accent.opacity(0.25), radius: 10, y: 4)

            VStack(alignment: .leading, spacing: 1) {
                Text("AULA")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(2.6)
                    .foregroundStyle(Theme.text)
                Text("CONTROL")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2.2)
                    .foregroundStyle(Theme.secondary)
            }
        }
    }

    private func sidebarButton(_ section: AppSection) -> some View {
        let selected = model.section == section
        return Button {
            withAnimation(.easeOut(duration: 0.16)) { model.section = section }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                    .foregroundStyle(selected ? Theme.accent : Theme.secondary)
                Text(section.title)
                    .font(.system(size: 12.5, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Theme.text : Theme.secondary)
                Spacer()
                if section == .macRemap && model.remapRunning {
                    Circle().fill(Theme.success).frame(width: 5, height: 5)
                }
                if section == .device && model.connection.kind == .wired {
                    Circle().fill(Theme.accent).frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? Color.white.opacity(0.065) : .clear)
            )
            .overlay(alignment: .leading) {
                if selected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.accent)
                        .frame(width: 2.5, height: 16)
                        .offset(x: -1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ConnectionCard: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Circle()
                    .fill(model.connectionColor)
                    .frame(width: 7, height: 7)
                    .shadow(color: model.connectionColor.opacity(0.8), radius: 5)
                Text(model.connection.kind == .absent ? "No keyboard" : model.connection.product)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Spacer()
                if model.isPreview {
                    Text("PREVIEW")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.blue)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.blue.opacity(0.14)))
                }
            }
            HStack(spacing: 5) {
                Image(systemName: model.connection.kind.symbol)
                    .font(.system(size: 9, weight: .semibold))
                Text(model.hardwareStatusText)
                    .font(.system(size: 10.5, weight: .medium))
                Spacer()
                Text(model.connection.kind.supportsHardwareConfig ? "CONFIG READY" : "READ ONLY")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(0.6)
            }
            .foregroundStyle(model.connection.kind.supportsHardwareConfig ? Theme.secondary : Theme.accent.opacity(0.8))

            if model.connection.kind == .bluetooth {
                Text("Connect USB-C for lighting, remaps and macros.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.sidebarElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }
}

struct WindowConfigurator: NSViewRepresentable {    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.title = "AULA Control"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = NSColor(Theme.background)
            window.minSize = NSSize(width: 1120, height: 720)
            if window.frame.width < 1200 {
                window.setContentSize(NSSize(width: 1240, height: 820))
                window.center()
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class AulaAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let window = NSApp.windows.first else { return }
            if window.frame.width < 1200 {
                window.setContentSize(NSSize(width: 1240, height: 820))
                window.center()
            }
        }
    }
}

@main
struct AulaControlApp: App {
    @NSApplicationDelegateAdaptor(AulaAppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Keyboard") {
                Button("Apply Saved Configuration") { model.pushAll() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Divider()
                Button("Overview") { model.section = .overview }.keyboardShortcut("1", modifiers: .command)
                Button("Lighting") { model.section = .lighting }.keyboardShortcut("2", modifiers: .command)
                Button("Per-Key RGB") { model.section = .perKey }.keyboardShortcut("3", modifiers: .command)
                Button("Keymap") { model.section = .keymap }.keyboardShortcut("4", modifiers: .command)
                Button("Macros") { model.section = .macros }.keyboardShortcut("5", modifiers: .command)
                Button("Mac Remap") { model.section = .macRemap }.keyboardShortcut("6", modifiers: .command)
                Button("Device") { model.section = .device }.keyboardShortcut("7", modifiers: .command)
                Button("Settings") { model.section = .settings }.keyboardShortcut("8", modifiers: .command)
                Divider()
                Button("New Macro") { model.addMacro() }.keyboardShortcut("n", modifiers: .command)
                Button(model.demoMode ? "Exit Preview Mode" : "Enter Preview Mode") {
                    model.demoMode.toggle()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                Divider()
                Button("Apply Lighting") { model.applyLighting() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Button("Apply Per-Key RGB") { model.applyPerKey() }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                Button("Apply Keymap") { model.applyKeymap() }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                Button("Load Mac Keymap Preset") {
                    model.state.keymap = RemapPresets.mac
                    model.selectedKey = "lalt"
                    model.section = .keymap
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                Button(model.state.macRemap.enabled ? "Disable macOS Remapping" : "Enable macOS Remapping") {
                    model.setMacRemapEnabled(!model.state.macRemap.enabled)
                }
                .keyboardShortcut("j", modifiers: [.command, .shift])
                Divider()
                Button("Sync LCD Clock") { model.syncClock() }
                Button("Quit AULA Control") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}
