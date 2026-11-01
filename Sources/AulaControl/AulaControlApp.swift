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
                .padding(.horizontal, 16)
                .padding(.top, 44)
                .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 18) {
                ForEach(grouped, id: \.0) { group, sections in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.tertiary)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 4)
                        ForEach(sections) { section in
                            sidebarButton(section)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 20)

            ConnectionCard()
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
        }
        .frame(width: 220)
        .background(Theme.sidebar)
    }

    /// Read from the bundle so the sidebar matches the release; an unbundled `swift run` build has
    /// no Info.plist and shows the model only.
    private var subtitle: String {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return "F108 Pro"
        }
        return "F108 Pro · v\(version)"
    }

    private var brand: some View {
        HStack(spacing: 10) {
            // A single keycap as the mark: skirt plus inset face, legend in mono.
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(hex: 0x17181B))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Theme.strokeStrong, lineWidth: 1)
                    )
                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                    .fill(Color(hex: 0x26282C))
                    .frame(width: 22, height: 20)
                    .overlay(
                        Text("A")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.accent)
                    )
                    .padding(.top, 2)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 0) {
                Text("AULA Control")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(subtitle)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Theme.tertiary)
            }
        }
    }

    private func sidebarButton(_ section: AppSection) -> some View {
        SidebarRow(section: section, selected: model.section == section) {
            model.section = section
        }
    }
}

private struct SidebarRow: View {
    @EnvironmentObject var model: AppModel
    let section: AppSection
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: section.icon)
                    .font(.system(size: 12, weight: .regular))
                    .frame(width: 16)
                    .foregroundStyle(selected ? Theme.accent : Theme.secondary)
                Text(section.title)
                    .font(.system(size: 12.5, weight: selected ? .medium : .regular))
                    .foregroundStyle(selected ? Theme.text : Theme.text.opacity(0.78))
                Spacer(minLength: 4)
                if section == .macRemap && model.remapRunning {
                    Circle().fill(Theme.success).frame(width: 5, height: 5)
                }
                Text(section.shortcut)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Theme.tertiary)
                    .opacity(selected || hovering ? 1 : 0.6)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .fill(selected ? Theme.cardRaised : (hovering ? Theme.sidebarElevated : .clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct ConnectionCard: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Circle()
                    .fill(model.connectionColor)
                    .frame(width: 6, height: 6)
                Text(model.connection.kind == .absent ? "No keyboard" : model.connection.product)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if model.isPreview {
                    Text("Preview")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.blue)
                } else if let level = model.batteryPercent {
                    BatteryIndicator(level: level)
                }
            }
            HStack(spacing: 5) {
                Image(systemName: model.connection.kind.symbol)
                    .font(.system(size: 9.5, weight: .medium))
                Text(model.hardwareStatusText)
                    .font(.system(size: 11))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(model.connection.kind == .absent ? "" : (model.connection.kind.supportsHardwareConfig ? "config" : "typing only"))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(model.connection.kind.supportsHardwareConfig ? Theme.tertiary : Theme.accent)
            }
            .foregroundStyle(Theme.secondary)

            if model.connection.kind == .bluetooth {
                Text("Connect USB-C for lighting, remaps and macros.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.sidebarElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
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

/// Finds and restores the main window. The app keeps running after its window closes so Mac remap
/// stays active; this brings the window back from the Dock, the Window menu and the Keyboard menu.
@MainActor
enum MainWindow {
    static let id = "main"
    static let menuTitle = "AULA Control"

    /// The main window if it is on screen or minimized. Closed windows can linger in
    /// `NSApp.windows` but are neither, so they are skipped.
    private static var existing: NSWindow? {
        NSApp.windows.first { $0.canBecomeMain && ($0.isVisible || $0.isMiniaturized) }
    }

    static func show(open: (() -> Void)? = nil) {
        NSApp.activate(ignoringOtherApps: true)
        if let window = existing {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else if let open {
            open()
        } else {
            openFromWindowMenu()
        }
    }

    /// SwiftUI only hands out `openWindow` inside views, so code outside a view (the Dock handler)
    /// runs the Window menu item that owns it.
    private static func openFromWindowMenu() {
        guard let menu = NSApp.windowsMenu ?? NSApp.mainMenu?.item(withTitle: "Window")?.submenu,
              let index = menu.items.firstIndex(where: { $0.title == menuTitle && $0.keyEquivalent == "0" })
        else { return }
        menu.performActionForItem(at: index)
    }
}

/// Window → AULA Control (⌘0): reopens the main window, or focuses it if it is already open.
struct ShowMainWindowButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(MainWindow.menuTitle) {
            MainWindow.show { openWindow(id: MainWindow.id) }
        }
        .keyboardShortcut("0", modifiers: .command)
    }
}

final class AulaAppDelegate: NSObject, NSApplicationDelegate {
    /// Dock click with no window on screen: bring the main window back. Returning false stops AppKit
    /// from also running its default reopen, which would otherwise do nothing for this app.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }
        MainActor.assumeIsolated { MainWindow.show() }
        return false
    }

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

    /// Switches page and brings the window back if it was closed.
    private func show(_ section: AppSection) {
        model.section = section
        MainWindow.show()
    }

    var body: some Scene {
        WindowGroup(id: MainWindow.id) {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(before: .windowArrangement) {
                ShowMainWindowButton()
                Divider()
            }
            CommandMenu("Keyboard") {
                Button("Apply Saved Configuration") { model.pushAll() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Divider()
                Button("Overview") { show(.overview) }.keyboardShortcut("1", modifiers: .command)
                Button("Lighting") { show(.lighting) }.keyboardShortcut("2", modifiers: .command)
                Button("Per-Key RGB") { show(.perKey) }.keyboardShortcut("3", modifiers: .command)
                Button("Keymap") { show(.keymap) }.keyboardShortcut("4", modifiers: .command)
                Button("Macros") { show(.macros) }.keyboardShortcut("5", modifiers: .command)
                Button("Device") { show(.device) }.keyboardShortcut("6", modifiers: .command)
                Button("Mac Remap") { show(.macRemap) }.keyboardShortcut("7", modifiers: .command)
                Button("Settings") { show(.settings) }.keyboardShortcut("8", modifiers: .command)
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
