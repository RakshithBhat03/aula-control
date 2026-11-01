import SwiftUI
import AulaKit

struct ActionEditor: View {
    enum Kind: String, CaseIterable, Identifiable {
        case key = "Single key"
        case combo = "Shortcut"
        case media = "Media"
        case macro = "Macro"
        case disabled = "Disabled"
        case none = "Default"
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .key: return "keyboard"
            case .combo: return "command"
            case .media: return "playpause"
            case .macro: return "record.circle"
            case .disabled: return "nosign"
            case .none: return "arrow.uturn.backward"
            }
        }
    }

    let key: KeyCap
    let current: KeyAction?
    let macros: [Macro]
    let onChange: (KeyAction?) -> Void

    @State private var kind: Kind = .none
    @State private var targetName: String = "a"
    @State private var modifiers: UInt8 = 0
    @State private var mediaUsage: UInt16 = 0xCD
    @State private var macroIndex: Int = 0

    private let keyGroups: [(String, [String])] = [
        ("Letters", ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "a", "s", "d", "f", "g", "h", "j", "k", "l", "z", "x", "c", "v", "b", "n", "m"]),
        ("Numbers", ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "minus", "equal", "grave"]),
        ("Function", ["esc", "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12"]),
        ("Editing", ["tab", "capslock", "enter", "backspace", "space", "insert", "delete", "home", "end", "pageup", "pagedown", "menu"]),
        ("Navigation", ["up", "down", "left", "right", "printscreen", "scrolllock", "pause"]),
        ("Punctuation", ["lbracket", "rbracket", "backslash", "semicolon", "quote", "comma", "dot", "slash"]),
        ("Numpad", ["numlock", "numslash", "numstar", "numminus", "num7", "num8", "num9", "numplus", "num4", "num5", "num6", "num1", "num2", "num3", "numenter", "num0", "numdot"]),
    ]

    /// Physical modifier order used for shortcut legends, matching how macOS menus print them.
    private let modifierOrder: [(symbol: String, name: String, bits: UInt8)] = [
        ("⌃", "Control", ModifierBits.leftControl | ModifierBits.rightControl),
        ("⇧", "Shift", ModifierBits.leftShift | ModifierBits.rightShift),
        ("⌥", "Option", ModifierBits.leftOption | ModifierBits.rightOption),
        ("⌘", "Command", ModifierBits.leftCommand | ModifierBits.rightCommand),
    ]

    private var targetKey: KeyCap? { KeyLayout.f108Pro.key(named: targetName) }

    private var isMapped: Bool { !(current?.isNoOp ?? true) }

    private var currentDescription: String {
        guard let current, !current.isNoOp else { return "Factory behavior" }
        return current.displayName
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            hairline

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Action")
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Kind.allCases) { option in
                        kindTile(option)
                    }
                }
            }

            hairline

            VStack(alignment: .leading, spacing: 12) {
                kindEditor
                outputRow
            }

            hairline

            HStack {
                Button {
                    kind = .none
                    emit()
                } label: {
                    Label("Reset key", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(GhostButtonStyle())
                Spacer()
                Text("Saved automatically")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.tertiary)
            }
        }
        .onAppear { syncFromCurrent() }
        .onChange(of: key.name) { _ in syncFromCurrent() }
        .onChange(of: current) { _ in syncFromCurrent() }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(keyDisplayName(key))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                StatusPill(text: currentDescription, color: isMapped ? Theme.accent : Theme.tertiary)
                    .lineLimit(1)
            }

            HStack(spacing: 0) {
                IdentifierReadout(label: "Key", value: key.name)
                readoutDivider
                IdentifierReadout(label: "LED", value: String(format: "%03d", key.light))
                readoutDivider
                IdentifierReadout(label: "HID", value: String(format: "0x%02X", key.usage))
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .fill(Theme.field)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var kindEditor: some View {
        switch kind {
        case .none:
            caption("Keeps its factory behavior on this layer.")

        case .disabled:
            caption("Blocked on this layer. Nothing is sent to the Mac.")

        case .key:
            targetPicker(includeModifiers: true) { name in
                targetName = name
                emit()
            }
            caption("Any key, including modifiers. A modifier target is held while the key is down.")

        case .combo:
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Hold modifiers")
                HStack(spacing: 6) {
                    modifierToggle("⌃", "Control", ModifierBits.leftControl)
                    modifierToggle("⇧", "Shift", ModifierBits.leftShift)
                    modifierToggle("⌥", "Option", ModifierBits.leftOption)
                    modifierToggle("⌘", "Command", ModifierBits.leftCommand)
                }
            }
            targetPicker(includeModifiers: false) { name in
                targetName = name
                emit()
            }
            caption("Works onboard and in macOS remapping.")

        case .media:
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Media action")
                Menu {
                    ForEach(ConsumerControl.names, id: \.usage) { item in
                        Button(item.name) {
                            mediaUsage = item.usage
                            emit()
                        }
                    }
                } label: {
                    menuLabel(ConsumerControl.name(for: mediaUsage) ?? "Choose")
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)
                .fixedSize(horizontal: false, vertical: true)
            }

        case .macro:
            if macros.isEmpty {
                EmptyState(
                    icon: "record.circle",
                    title: "No macros",
                    message: "Record one in Macros, then bind it to this key."
                )
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Play macro")
                    Menu {
                        ForEach(Array(macros.enumerated()), id: \.element.id) { index, macro in
                            Button("\(slotLabel(index))  \(macro.name)") {
                                macroIndex = index
                                emit()
                            }
                        }
                    } label: {
                        menuLabel(
                            macros.indices.contains(macroIndex) ? macros[macroIndex].name : "Choose",
                            prefix: macros.indices.contains(macroIndex) ? slotLabel(macroIndex) : nil
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: false, vertical: true)
                }
                if macros.indices.contains(macroIndex) {
                    Text(macros[macroIndex].summary.isEmpty ? "Empty macro" : macros[macroIndex].summary)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.tertiary)
                        .lineLimit(2)
                }
            }
        }
    }

    /// What the key will send with the editor's current state, shown as keycaps or a raw usage.
    private var outputRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Sends")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.secondary)
            Spacer(minLength: 8)
            outputValue
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var outputValue: some View {
        switch kind {
        case .none:
            ValueChip("factory", color: Theme.secondary)
        case .disabled:
            ValueChip("nothing", color: Theme.secondary)
        case .key:
            if let target = targetKey {
                KeyTag(legend(target))
            } else {
                ValueChip(targetName, color: Theme.secondary)
            }
        case .combo:
            if let target = targetKey {
                KeyCombo(modifierLegends(modifiers) + [legend(target)])
            } else {
                ValueChip(targetName, color: Theme.secondary)
            }
        case .media:
            ValueChip(String(format: "0x%04X", mediaUsage))
        case .macro:
            if macros.isEmpty {
                ValueChip("none", color: Theme.secondary)
            } else {
                ValueChip("M\(slotLabel(min(macroIndex, macros.count - 1)))")
            }
        }
    }

    // MARK: - Controls

    private func kindTile(_ option: Kind) -> some View {
        let selected = kind == option
        return SelectableTile(isSelected: selected, action: {
            kind = option
            emit()
        }) {
            HStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(selected ? Theme.accent : Theme.tertiary)
                    .frame(width: 13)
                Text(option.rawValue)
                    .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? Theme.text : Theme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func modifierToggle(_ symbol: String, _ name: String, _ bit: UInt8) -> some View {
        ModifierKeyToggle(symbol: symbol, name: name, isOn: modifiers & bit != 0) {
            modifiers ^= bit
            if kind == .combo { emit() }
        }
    }

    private func targetPicker(includeModifiers: Bool, onSelect: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Target key")
            Menu {
                ForEach(keyGroups, id: \.0) { group, names in
                    Section(group) {
                        ForEach(names, id: \.self) { name in
                            if let cap = KeyLayout.f108Pro.key(named: name) {
                                Button(keyDisplayName(cap)) { onSelect(name) }
                            }
                        }
                    }
                }
                if includeModifiers {
                    Section("Modifiers") {
                        ForEach(["lctrl", "lshift", "lalt", "lwin", "rctrl", "rshift", "ralt"], id: \.self) { name in
                            if let cap = KeyLayout.f108Pro.key(named: name) {
                                Button(keyDisplayName(cap)) { onSelect(name) }
                            }
                        }
                    }
                }
            } label: {
                menuLabel(targetKey.map(keyDisplayName) ?? targetName)
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.plain)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func menuLabel(_ text: String, prefix: String? = nil) -> some View {
        HStack(spacing: 8) {
            if let prefix {
                Text(prefix)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.tertiary)
            }
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Spacer(minLength: 6)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                .fill(Theme.field)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                .strokeBorder(Theme.strokeStrong, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    // MARK: - Small pieces

    private var hairline: some View {
        Rectangle().fill(Theme.stroke).frame(height: 1)
    }

    private var readoutDivider: some View {
        Rectangle().fill(Theme.stroke).frame(width: 1)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(Theme.secondary)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(Theme.captionFont)
            .foregroundStyle(Theme.tertiary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func slotLabel(_ index: Int) -> String {
        String(format: "%02d", index + 1)
    }

    /// Short keycap legend for a key, e.g. "A", "⌫", "L⌘".
    private func legend(_ cap: KeyCap) -> String {
        if let bit = Self.modifierBit(for: cap.usage) {
            let side = bit >= ModifierBits.rightControl ? "R" : "L"
            let symbol = modifierOrder.first(where: { $0.bits & bit != 0 }).map(\.symbol) ?? ""
            return side + symbol
        }
        if cap.name == "space" { return "Space" }
        if cap.label.isEmpty { return cap.name.capitalized }
        return cap.label
    }

    private func modifierLegends(_ bits: UInt8) -> [String] {
        modifierOrder.filter { bits & $0.bits != 0 }.map(\.symbol)
    }

    private func keyDisplayName(_ cap: KeyCap) -> String {
        if let bit = Self.modifierBit(for: cap.usage) {
            switch bit {
            case ModifierBits.leftControl: return "⌃ Left Control"
            case ModifierBits.leftShift: return "⇧ Left Shift"
            case ModifierBits.leftOption: return "⌥ Left Option"
            case ModifierBits.leftCommand: return "⌘ Left Command"
            case ModifierBits.rightControl: return "⌃ Right Control"
            case ModifierBits.rightShift: return "⇧ Right Shift"
            case ModifierBits.rightOption: return "⌥ Right Option"
            case ModifierBits.rightCommand: return "⌘ Right Command"
            default: break
            }
        }
        if cap.name == "space" { return "Space" }
        if cap.label.isEmpty { return cap.name.capitalized }
        if let sub = cap.sublabel, !["⌫", "⏎", "⇧", "⌃", "⌥", "⌘", "☰"].contains(cap.label) {
            return "\(cap.label) \(sub)"
        }
        return cap.label
    }

    // MARK: - State

    private func emit() {
        switch kind {
        case .none:
            onChange(nil)
        case .disabled:
            onChange(.disabled)
        case .key:
            guard let key = targetKey else { return }
            if let bit = Self.modifierBit(for: key.usage) {
                onChange(.modifier(bit))
            } else {
                onChange(.key(usage: key.usage))
            }
        case .combo:
            guard let key = targetKey else { return }
            onChange(.key(usage: key.usage, modifiers: modifiers))
        case .media:
            onChange(.consumer(mediaUsage))
        case .macro:
            guard !macros.isEmpty else { return }
            let index = min(macroIndex, macros.count - 1)
            let macro = macros[index]
            onChange(.macro(
                index: UInt8(index),
                mode: UInt8(macro.playMode.rawValue),
                count: UInt8(min(99, macro.repeatCount))
            ))
        }
    }

    private func syncFromCurrent() {
        guard let current, !current.isNoOp else {
            kind = .none
            return
        }
        switch current {
        case .disabled:
            kind = .disabled
        case .modifier(let bits):
            kind = .key
            if let name = KeyLayout.f108Pro.keys.first(where: { Self.modifierBit(for: $0.usage) == bits })?.name {
                targetName = name
            }
        case .key(let usage, let mods):
            kind = mods == 0 ? .key : .combo
            targetName = KeyLayout.f108Pro.key(usage: usage)?.name ?? "a"
            modifiers = mods
        case .consumer(let usage):
            kind = .media
            mediaUsage = usage
        case .macro(let index, _, _):
            kind = .macro
            macroIndex = Int(index)
        case .special(let a, let b):
            kind = .none
            _ = (a, b)
        case .mouse:
            kind = .none
        case .none:
            kind = .none
        }
    }

    static func modifierBit(for usage: UInt8) -> UInt8? {
        switch usage {
        case 0xE0: return ModifierBits.leftControl
        case 0xE1: return ModifierBits.leftShift
        case 0xE2: return ModifierBits.leftOption
        case 0xE3: return ModifierBits.leftCommand
        case 0xE4: return ModifierBits.rightControl
        case 0xE5: return ModifierBits.rightShift
        case 0xE6: return ModifierBits.rightOption
        case 0xE7: return ModifierBits.rightCommand
        default: return nil
        }
    }
}

/// Label above a mono value, one cell of the key's identifier strip.
private struct IdentifierReadout: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.tertiary)
            Text(value)
                .font(Theme.monoFont)
                .monospacedDigit()
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

/// A modifier drawn as a small keycap that latches on when clicked.
private struct ModifierKeyToggle: View {
    let symbol: String
    let name: String
    let isOn: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isOn ? Theme.accent : Theme.text)
                Text(name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isOn ? Theme.text : Theme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .fill(isOn ? Theme.accent.opacity(0.10) : (hovering ? Theme.cardRaised : Theme.field))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .strokeBorder(isOn ? Theme.accent.opacity(0.85) : Theme.strokeStrong, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(isOn ? "Release \(name)" : "Hold \(name)")
        .accessibilityLabel(name)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
