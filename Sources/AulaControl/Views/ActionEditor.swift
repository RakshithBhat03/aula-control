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

    private var targetKey: KeyCap? { KeyLayout.f108Pro.key(named: targetName) }

    private var currentDescription: String {
        guard let current, !current.isNoOp else { return "Factory behavior" }
        return current.displayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(keyDisplayName(key))
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("\(key.name) · index \(key.light)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.tertiary)
                }
                Spacer()
                StatusPill(
                    text: currentDescription,
                    color: (current?.isNoOp ?? true) ? Theme.tertiary : Theme.accent,
                    icon: (current?.isNoOp ?? true) ? "arrow.uturn.backward" : "bolt.fill"
                )
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Kind.allCases) { option in
                    kindButton(option)
                }
            }

            switch kind {
            case .none:
                Text("The physical key keeps its factory behavior on this layer.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.secondary)
                    .lineSpacing(2)

            case .disabled:
                Text("The key is blocked on this layer. Nothing is sent to the Mac.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.secondary)
                    .lineSpacing(2)

            case .key:
                targetPicker(includeModifiers: true) { name in
                    targetName = name
                    emit()
                }
                Text("Choose any key, including modifiers. Modifier targets become held modifiers.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.tertiary)

            case .combo:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hold modifiers")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                    HStack(spacing: 7) {
                        modifierChip("⌃", "Control", ModifierBits.leftControl)
                        modifierChip("⇧", "Shift", ModifierBits.leftShift)
                        modifierChip("⌥", "Option", ModifierBits.leftOption)
                        modifierChip("⌘", "Command", ModifierBits.leftCommand)
                    }
                }
                targetPicker(includeModifiers: false) { name in
                    targetName = name
                    emit()
                }
                Text("Example: ⌘ + C sends Copy. Shortcuts work on the keyboard itself and in macOS remapping.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.tertiary)

            case .media:
                VStack(alignment: .leading, spacing: 7) {
                    Text("Media action")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.secondary)
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
                        title: "No macros yet",
                        message: "Create a macro in the Macros section, then bind it to this key."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Play macro")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.secondary)
                        Menu {
                            ForEach(Array(macros.enumerated()), id: \.element.id) { index, macro in
                                Button("\(index + 1). \(macro.name)") {
                                    macroIndex = index
                                    emit()
                                }
                            }
                        } label: {
                            menuLabel(macros.indices.contains(macroIndex) ? macros[macroIndex].name : "Choose")
                        }
                        .menuStyle(.borderlessButton)
                        .buttonStyle(.plain)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    if macros.indices.contains(macroIndex) {
                        Text(macros[macroIndex].summary.isEmpty ? "Empty macro" : macros[macroIndex].summary)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(Theme.tertiary)
                            .lineLimit(2)
                    }
                }
            }

            Rectangle().fill(Theme.stroke).frame(height: 1)

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
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.tertiary)
            }
        }
        .onAppear { syncFromCurrent() }
        .onChange(of: key.name) { _ in syncFromCurrent() }
        .onChange(of: current) { _ in syncFromCurrent() }
    }

    private func kindButton(_ option: Kind) -> some View {
        let selected = kind == option
        return Button {
            kind = option
            emit()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: option.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(option.rawValue)
                    .font(.system(size: 9.5, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(selected ? Theme.accent : Theme.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? Theme.accent.opacity(0.10) : Color.white.opacity(0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(selected ? Theme.accent.opacity(0.45) : Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func modifierChip(_ symbol: String, _ name: String, _ bit: UInt8) -> some View {
        let active = modifiers & bit != 0
        return Button {
            modifiers ^= bit
            if kind == .combo { emit() }
        } label: {
            VStack(spacing: 2) {
                Text(symbol).font(.system(size: 13, weight: .semibold))
                Text(name).font(.system(size: 8.5, weight: .medium))
            }
            .foregroundStyle(active ? Color(hex: 0x1A1408) : Theme.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(active ? Theme.accent : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(active ? .clear : Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func targetPicker(includeModifiers: Bool, onSelect: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Target key")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.secondary)
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

    private func menuLabel(_ text: String) -> some View {        HStack {
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text)
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Theme.tertiary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.field)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

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
