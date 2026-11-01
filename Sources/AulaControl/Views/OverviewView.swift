import SwiftUI
import AulaKit

struct OverviewView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        PageScroll {
            PageHeader(
                eyebrow: "F108 Pro",
                title: "Overview",
                subtitle: "Connection, current lighting and remap state. Hardware settings are written over USB-C."
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
                    .help("Send lighting, per-key colors, keymap, macros and options to the keyboard")
                }
            }

            if model.connection.kind != .wired && !model.isPreview {
                connectionBanner
            }

            devicePanel

            // The table's nine form-height rows balance the shortcut list plus the setup steps, so
            // the two columns end on the same line without padding either one.
            SplitRow {
                capabilityTable
            } aside: {
                VStack(spacing: Theme.gutter) {
                    shortcutsPanel
                    setupPanel
                }
            }
        }
    }

    // MARK: - Connection notice

    private var bannerTitle: String {
        switch model.connection.kind {
        case .absent: return "Keyboard not detected"
        case .dongle: return "Connected over 2.4 GHz"
        default: return "Connected over Bluetooth"
        }
    }

    private var bannerDetail: String {
        model.connection.kind == .absent
            ? "Connect USB-C and switch the keyboard to wired mode, or pair it over Bluetooth in macOS."
            : "Typing and macOS remapping work. Lighting, per-key RGB and onboard settings need USB-C."
    }

    private var connectionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: model.connection.kind.symbol)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Theme.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(bannerTitle)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(bannerDetail)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                Text("Wired mode")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.tertiary)
                KeyCombo(["Fn", "4"])
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Press Fn plus 4 for wired mode")
        }
        .frame(minHeight: Theme.rowHeight)
        .padding(.horizontal, Theme.panelInset)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .fill(Theme.field)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(Theme.strokeStrong, lineWidth: 1)
        )
    }

    // MARK: - Device panel

    private var devicePanel: some View {
        Card(padding: 0) {
            VStack(spacing: 0) {
                PanelHeaderBand(
                    model.connection.product.isEmpty ? "AULA F108 Pro" : model.connection.product,
                    detail: "Backlight preview and live readouts"
                ) {
                    HStack(spacing: 8) {
                        Button {
                            model.section = .lighting
                        } label: {
                            Label("Lighting", systemImage: "light.max")
                        }
                        .buttonStyle(GhostButtonStyle())

                        Button {
                            model.section = .perKey
                        } label: {
                            Label("Per-key RGB", systemImage: "paintpalette")
                        }
                        .buttonStyle(GhostButtonStyle())
                    }
                }

                KeyboardView(
                    colorFor: { key in
                        let hue = 0.06 + (key.x / 22.5) * 0.58
                        return AulaRGB.hue(hue, saturation: 0.78, value: 1)
                    },
                    isInteractive: false
                )
                .padding(Theme.panelInset + Theme.gutter / 2)
                .frame(maxWidth: .infinity)

                Hairline()

                readoutStrip
            }
        }
    }

    private var readoutStrip: some View {
        HStack(alignment: .top, spacing: 0) {
            connectionReadout
            Hairline(axis: .vertical)
            effectReadout
            Hairline(axis: .vertical)
            brightnessReadout
            Hairline(axis: .vertical)
            onboardReadout
            Hairline(axis: .vertical)
            macRemapReadout
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var usbIdentifier: String {
        guard model.connection.vendorID != 0 else { return "—" }
        return String(format: "%04X:%04X", model.connection.vendorID, model.connection.productID)
    }

    private var connectionReadout: some View {
        ReadoutCell(label: "Connection") {
            StatusDot(color: model.connectionColor)
            ReadoutValue(model.hardwareStatusText)
        } controls: {
            Text("USB ID")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.tertiary)
            Spacer(minLength: 0)
            ValueChip(usbIdentifier, color: Theme.secondary)
        }
    }

    private var effectReadout: some View {
        ReadoutCell(label: "Effect") {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(model.state.lighting.color))
                .frame(width: 10, height: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Theme.strokeStrong, lineWidth: 1)
                )
            ReadoutValue(model.state.lighting.mode.name)
        } controls: {
            ValueChip("#\(model.state.lighting.color.hex)", color: Theme.secondary)
            Spacer(minLength: 0)
            Button {
                showEffectMenu()
            } label: {
                Text("Change")
            }
            .buttonStyle(GhostButtonStyle())
            .fixedSize()
            .help("Choose a backlight effect")
        }
    }

    /// A native menu under a ghost button, so the control matches the other cells' buttons
    /// instead of taking the system pop-up button look.
    private func showEffectMenu() {
        let menu = NSMenu()
        for mode in LightingMode.allCases {
            menu.addItem(ClosureMenuItem(title: mode.name, checked: mode == model.state.lighting.mode) {
                model.setLightingMode(mode)
            })
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private var brightnessReadout: some View {
        ReadoutCell(label: "Brightness") {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                ReadoutValue("\(model.state.lighting.brightness)", monospaced: true)
                Text("/ 5")
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.tertiary)
            }
        } controls: {
            Slider(
                value: Binding(
                    get: { Double(model.state.lighting.brightness) },
                    set: { model.state.lighting.brightness = UInt8($0) }
                ),
                in: 0...5, step: 1
            )
            .controlSize(.small)
            .tint(Theme.accent)
            .accessibilityLabel("Brightness")

            Button("Send") {
                model.applyLighting()
            }
            .buttonStyle(GhostButtonStyle())
            .disabled(!model.canUseHardware && !model.isPreview)
            .help("Send lighting to the keyboard")
        }
    }

    private var onboardReadout: some View {
        ReadoutCell(label: "Onboard remaps") {
            ReadoutValue("\(model.state.keymap.count + model.state.fnKeymap.count)", monospaced: true)
        } controls: {
            LayerCount(name: "Base", count: model.state.keymap.count)
            LayerCount(name: "Fn", count: model.state.fnKeymap.count)
                .padding(.leading, 4)
            Spacer(minLength: 0)
            Button("Edit") { model.section = .keymap }
                .buttonStyle(GhostButtonStyle())
                .help("Open Keymap")
        }
    }

    private var macRemapReadout: some View {
        ReadoutCell(label: "Mac remap") {
            StatusDot(color: model.remapRunning ? Theme.success : Theme.tertiary)
            ReadoutValue(model.remapRunning ? "Active" : "Inactive")
        } controls: {
            Toggle("Mac remap", isOn: Binding(
                get: { model.state.macRemap.enabled },
                set: { model.setMacRemapEnabled($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(Theme.accent)

            Spacer(minLength: 0)

            Button("Configure") { model.section = .macRemap }
                .buttonStyle(GhostButtonStyle())
        }
    }

    // MARK: - Capabilities

    private struct Capability: Identifiable {
        let name: String
        let wired: Bool
        let bluetooth: Bool
        var id: String { name }
    }

    private let capabilities: [Capability] = [
        Capability(name: "Backlight effects and color", wired: true, bluetooth: false),
        Capability(name: "Per-key RGB", wired: true, bluetooth: false),
        Capability(name: "Onboard remap, base and Fn layers", wired: true, bluetooth: false),
        Capability(name: "Macros stored on the keyboard", wired: true, bluetooth: false),
        Capability(name: "Sleep, debounce and key locks", wired: true, bluetooth: false),
        Capability(name: "LCD clock sync", wired: true, bluetooth: false),
        Capability(name: "Typing and media keys", wired: true, bluetooth: true),
        Capability(name: "Per-key macOS remap", wired: true, bluetooth: true),
        Capability(name: "Macro playback on this Mac", wired: true, bluetooth: true),
    ]

    private let transportColumnWidth: CGFloat = 88

    private var capabilityTable: some View {
        Card(padding: 0, fillHeight: true) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeaderBand("What works where", detail: "Hardware settings use the wired config interface.") {
                    StatusPill(
                        text: model.connection.kind.supportsHardwareConfig ? "USB ready" : "USB needed",
                        color: model.connection.kind.supportsHardwareConfig ? Theme.success : Theme.tertiary,
                        icon: model.connection.kind.supportsHardwareConfig ? "checkmark" : "cable.connector"
                    )
                }

                HStack(spacing: 0) {
                    Text("Capability")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    transportHeader("USB-C", isCurrent: model.connection.kind == .wired)
                    transportHeader("Bluetooth", isCurrent: model.connection.kind == .bluetooth)
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.tertiary)
                .frame(height: Self.tableRowHeight)
                .padding(.horizontal, Theme.panelInset)
                .background(Theme.field)

                Hairline()

                ForEach(Array(capabilities.enumerated()), id: \.element.id) { index, capability in
                    if index > 0 {
                        Hairline().padding(.leading, Theme.panelInset)
                    }
                    HStack(spacing: 0) {
                        Text(capability.name)
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        supportMark(capability.wired)
                        supportMark(capability.bluetooth)
                    }
                    .frame(height: Theme.rowHeight)
                    .padding(.horizontal, Theme.panelInset)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "\(capability.name): USB-C \(capability.wired ? "yes" : "no"), Bluetooth \(capability.bluetooth ? "yes" : "no")"
                    )
                }

                Spacer(minLength: 0)

                Hairline()

                footnote("Bluetooth does not expose the config interface; this is an AULA firmware limitation. Secure Input fields bypass macOS remapping on any transport.")
            }
        }
    }

    /// Height of compact list rows: the table's column header and the shortcut list.
    private static let tableRowHeight: CGFloat = 36

    private func transportHeader(_ title: String, isCurrent: Bool) -> some View {
        HStack(spacing: 5) {
            if isCurrent {
                Circle().fill(Theme.success).frame(width: 5, height: 5)
            }
            Text(title)
                .foregroundStyle(isCurrent ? Theme.text : Theme.tertiary)
        }
        .frame(width: transportColumnWidth)
        .help(isCurrent ? "Current connection" : "")
    }

    private func supportMark(_ supported: Bool) -> some View {
        Group {
            if supported {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.text.opacity(0.85))
            } else {
                Rectangle()
                    .fill(Theme.tertiary)
                    .frame(width: 8, height: 1.5)
            }
        }
        .frame(width: transportColumnWidth)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(Theme.captionFont)
            .foregroundStyle(Theme.tertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.panelInset)
            .padding(.vertical, 12)
    }

    // MARK: - Aside

    private var shortcutsPanel: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeaderBand("Hardware shortcuts", detail: "Handled by the firmware, no app needed.")
                shortcutRow(["Fn", "4"], "USB-C wired")
                shortcutRow(["Fn", "1–3"], "Bluetooth slot 1–3")
                shortcutRow(["Fn", "E"], "macOS device mode")
                shortcutRow(["Fn", "L-Shift"], "Light bar effect")
                shortcutRow(["Fn", "R-Shift"], "Side strip effect")
                shortcutRow(["Fn", "/"], "Side strip color", isLast: true)
            }
        }
    }

    private func shortcutRow(_ keys: [String], _ action: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                KeyCombo(keys)
                Spacer(minLength: 8)
                Text(action)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
            }
            .frame(height: Self.tableRowHeight)
            .padding(.horizontal, Theme.panelInset)
            if !isLast {
                Hairline().padding(.leading, Theme.panelInset)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var setupPanel: some View {
        Card(padding: 0, fillHeight: true) {
            VStack(alignment: .leading, spacing: 0) {
                PanelHeaderBand("Setup")
                stepRow(
                    number: 1,
                    title: "Connect over USB-C",
                    detail: "Settings are sent over the wired config interface.",
                    done: model.connection.kind == .wired
                )
                Hairline().padding(.leading, Theme.panelInset)
                stepRow(
                    number: 2,
                    title: "Set lighting",
                    detail: "Pick an effect or paint individual keys.",
                    done: !model.state.perKey.isEmpty || model.state.lighting.mode != .rolling
                )
                Hairline().padding(.leading, Theme.panelInset)
                stepRow(
                    number: 3,
                    title: "Enable Mac remap",
                    detail: "Per-device remapping, configured in Mac remap.",
                    done: model.state.macRemap.enabled
                )
                // Pin the note to the panel's bottom so it lines up with the table's footnote.
                Spacer(minLength: 0)
                Hairline()
                footnote("Settings are saved locally and can be re-applied at any time.")
            }
        }
    }

    private func stepRow(number: Int, title: String, detail: String, done: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 10) {
                StepMarker(number: number, done: done)
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(done ? Theme.secondary : Theme.text)
            }
            Text(detail)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, StepMarker.size + 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.panelInset)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? "Done" : "Not done")
    }
}

// MARK: - Readout strip parts

/// One cell of the readout strip. Every cell has the same three tiers (caption, live value, control
/// row) at fixed heights, so labels, values and controls share baselines across the strip.
fileprivate struct ReadoutCell<Value: View, Controls: View>: View {
    static var valueHeight: CGFloat { 20 }
    static var controlHeight: CGFloat { 28 }

    let label: String
    @ViewBuilder var value: Value
    @ViewBuilder var controls: Controls

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.tertiary)
                .lineLimit(1)
            HStack(spacing: 7) { value }
                .frame(height: Self.valueHeight, alignment: .leading)
                .padding(.top, 4)
            HStack(spacing: 8) { controls }
                .frame(height: Self.controlHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(Theme.panelInset)
    }
}

fileprivate struct ReadoutValue: View {
    let text: String
    var monospaced = false

    init(_ text: String, monospaced: Bool = false) {
        self.text = text
        self.monospaced = monospaced
    }

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium, design: monospaced ? .monospaced : .default))
            .monospacedDigit()
            .foregroundStyle(Theme.text)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

fileprivate struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle().fill(color).frame(width: 6, height: 6)
    }
}

/// A labeled count, e.g. "Base 3", used to break a total down without dot-separated strings.
fileprivate struct LayerCount: View {
    let name: String
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(name)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.tertiary)
            Text("\(count)")
                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(Theme.secondary)
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

/// Menu item that runs a closure, for menus built on demand from SwiftUI actions.
fileprivate final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, checked: Bool, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
        state = checked ? .on : .off
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func fire() { handler() }
}

/// Fixed-size step marker: a numbered ring while pending, a filled check once done, so every
/// step reads as the same object in either state.
fileprivate struct StepMarker: View {
    static let size: CGFloat = 18

    let number: Int
    let done: Bool

    var body: some View {
        ZStack {
            if done {
                Circle().fill(Theme.success.opacity(0.16))
                Circle().strokeBorder(Theme.success.opacity(0.55), lineWidth: 1)
                Image(systemName: "checkmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(Theme.success)
            } else {
                Circle().fill(Theme.field)
                Circle().strokeBorder(Theme.strokeStrong, lineWidth: 1)
                Text("\(number)")
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondary)
            }
        }
        .frame(width: Self.size, height: Self.size)
    }
}
