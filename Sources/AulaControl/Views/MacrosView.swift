import SwiftUI
import AppKit
import AulaKit

struct MacrosView: View {
    @EnvironmentObject var model: AppModel
    @State private var selectedID: UUID?
    @State private var recording = false
    @State private var eventMonitor: Any?
    @State private var textToAdd = ""
    @State private var recordingCount = 0

    private var selectedIndex: Int? {
        guard let selectedID else { return nil }
        return model.state.macros.firstIndex { $0.id == selectedID }
    }

    private var selectedMacro: Macro? {
        guard let index = selectedIndex else { return nil }
        return model.state.macros[index]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    eyebrow: "HARDWARE · USB + MACOS",
                    title: "Macros",
                    subtitle: "Record a sequence once and play it from any key. Macros live on the keyboard, so they work on any computer you plug it into."
                ) {
                    HStack(spacing: 10) {
                        Button {
                            model.addMacro()
                            selectedID = model.state.macros.last?.id
                        } label: {
                            Label("New macro", systemImage: "plus")
                        }
                        .buttonStyle(GhostButtonStyle())

                        Button {
                            model.uploadMacros()
                        } label: {
                            Label("Upload macros", systemImage: "arrow.down.to.line")
                        }
                        .buttonStyle(AccentButtonStyle(enabled: model.canUseHardware || model.isPreview))
                        .disabled(model.isBusy || !(model.canUseHardware || model.isPreview))
                    }
                }

                if model.state.macros.isEmpty {
                    Card {
                        VStack(spacing: 18) {
                            EmptyState(
                                icon: "record.circle",
                                title: "No macros yet",
                                message: "Create a macro, record a few keys, then bind it to a key on the Keymap page."
                            )
                            Button {
                                model.addMacro()
                                selectedID = model.state.macros.last?.id
                            } label: {
                                Label("Create your first macro", systemImage: "plus")
                            }
                            .buttonStyle(AccentButtonStyle())
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    HStack(alignment: .top, spacing: 18) {
                        macroList
                            .frame(width: 270)
                        if let macro = selectedMacro, let index = selectedIndex {
                            editor(macro: macro, index: index)
                        } else {
                            Card {
                                EmptyState(icon: "hand.point.up.left", title: "Select a macro", message: "Choose a macro from the list to edit its steps.")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            if selectedID == nil { selectedID = model.state.macros.first?.id }
        }
        .onChange(of: model.focusMacroID) { newValue in
            if let newValue {
                selectedID = newValue
                model.focusMacroID = nil
            }
        }
        .onDisappear { stopRecording() }
    }

    private var macroList: some View {
        Card(padding: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Macro bank")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(Theme.tertiary)
                    Spacer()
                    Text("\(model.state.macros.count) / 100")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.tertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

                ForEach(Array(model.state.macros.enumerated()), id: \.element.id) { index, macro in
                    let selected = selectedID == macro.id
                    Button {
                        selectedID = macro.id
                    } label: {
                        HStack(spacing: 10) {
                            Text(String(format: "%02d", index + 1))
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(selected ? Theme.accent : Theme.tertiary)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(macro.name)
                                    .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(1)
                                Text(macro.steps.isEmpty ? "Empty" : "\(macro.steps.count) steps")
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(Theme.tertiary)
                            }
                            Spacer()
                            if selected {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selected ? Theme.accent.opacity(0.08) : .clear)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func editor(macro: Macro, index: Int) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Eyebrow(text: "MACRO \(String(format: "%02d", index + 1))")
                        TextField("Macro name", text: Binding(
                            get: { model.state.macros[safe: index]?.name ?? macro.name },
                            set: { name in
                                var updated = macro
                                updated.name = name
                                model.updateMacro(updated)
                            }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    }
                    Spacer()
                    Button {
                        model.duplicateMacro(macro)
                        selectedID = model.state.macros.last?.id
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(GhostButtonStyle())
                    .help("Duplicate")

                    Button {
                        model.deleteMacro(macro)
                        selectedID = model.state.macros.first?.id
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(GhostButtonStyle(danger: true))
                    .help("Delete")
                }

                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Playback")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Theme.secondary)
                        Menu {
                            ForEach(MacroPlayMode.allCases, id: \.self) { mode in
                                Button(mode.name) {
                                    var updated = macro
                                    updated.playMode = mode
                                    model.updateMacro(updated)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(macro.playMode.name)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(Theme.text)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Theme.tertiary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 7).fill(Theme.field))
                            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.stroke, lineWidth: 1))
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }

                    if macro.playMode == .repeatCount {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Repeat count")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(Theme.secondary)
                            Stepper("\(macro.repeatCount)×", value: Binding(
                                get: { macro.repeatCount },
                                set: { count in
                                    var updated = macro
                                    updated.repeatCount = count
                                    model.updateMacro(updated)
                                }
                            ), in: 1...99)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                        }
                    }

                    Spacer()

                    Button {
                        toggleRecording()
                    } label: {
                        Label(recording ? "Stop recording" : "Record keys", systemImage: recording ? "stop.fill" : "record.circle")
                    }
                    .buttonStyle(GhostButtonStyle())
                }

                if recording {
                    HStack(spacing: 8) {
                        Circle().fill(Theme.danger).frame(width: 7, height: 7)
                        Text("Recording — type on the AULA keyboard. Press Esc to stop.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.danger)
                        Spacer()
                        Text("\(recordingCount) captured")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Theme.secondary)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Theme.danger.opacity(0.07)))
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.danger.opacity(0.2), lineWidth: 1))
                }

                Rectangle().fill(Theme.stroke).frame(height: 1)

                HStack {
                    Text("Steps")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("· \(macro.steps.count)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.tertiary)
                    Spacer()
                    Menu {
                        Button("50 ms") { addDelay(50, macro: macro) }
                        Button("100 ms") { addDelay(100, macro: macro) }
                        Button("250 ms") { addDelay(250, macro: macro) }
                        Button("500 ms") { addDelay(500, macro: macro) }
                        Divider()
                        Button("Left click") { addMouse(1, macro: macro) }
                        Button("Right click") { addMouse(2, macro: macro) }
                        Button("Middle click") { addMouse(3, macro: macro) }
                    } label: {
                        Label("Add step", systemImage: "plus")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Theme.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Button {
                        var updated = macro
                        updated.steps.removeAll()
                        model.updateMacro(updated)
                    } label: {
                        Text("Clear")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Theme.tertiary)
                    }
                    .buttonStyle(.plain)
                }

                if macro.steps.isEmpty {
                    EmptyState(icon: "square.dashed", title: "No steps", message: "Press Record keys and type a sequence, or add text below.")
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(Array(macro.steps.enumerated()), id: \.offset) { stepIndex, step in
                                stepRow(step, stepIndex: stepIndex, macro: macro)
                            }
                        }
                    }
                    .frame(maxHeight: 230)
                }

                HStack(spacing: 8) {
                    TextField("Type text to append…", text: $textToAdd)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.field))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.stroke, lineWidth: 1))
                    Button {
                        guard !textToAdd.isEmpty else { return }
                        var updated = macro
                        updated.steps.append(contentsOf: Macro.typing(textToAdd).steps)
                        model.updateMacro(updated)
                        textToAdd = ""
                    } label: {
                        Text("Append")
                    }
                    .buttonStyle(GhostButtonStyle())
                }

                Rectangle().fill(Theme.stroke).frame(height: 1)

                HStack(spacing: 10) {
                    Button {
                        model.uploadMacros()
                    } label: {
                        Label("Send macros to keyboard", systemImage: "arrow.down.to.line")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AccentButtonStyle(enabled: model.canUseHardware || model.isPreview))
                    .disabled(model.isBusy || !(model.canUseHardware || model.isPreview))

                    Button {
                        model.section = .keymap
                    } label: {
                        Label("Bind to key", systemImage: "keyboard")
                    }
                    .buttonStyle(GhostButtonStyle())
                }

                Text("Macro slots are positional. Binding a macro to a key uses its slot number, so avoid deleting entries that are already assigned.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func stepRow(_ step: MacroStep, stepIndex: Int, macro: Macro) -> some View {
        HStack(spacing: 10) {
            Image(systemName: stepIcon(step))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(stepColor(step))
                .frame(width: 16)
            Text(stepLabel(step))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.text)
            if case .delay(let ms) = step {
                Text("\(ms) ms")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.tertiary)
            }
            Spacer()
            Button {
                var updated = macro
                updated.steps.remove(at: stepIndex)
                model.updateMacro(updated)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.white.opacity(0.022))
        )
    }

    private func stepIcon(_ step: MacroStep) -> String {
        switch step {
        case .key(_, let down): return down ? "arrow.down.circle" : "arrow.up.circle"
        case .mouse(_, let down): return down ? "computermouse.fill" : "computermouse"
        case .delay: return "timer"
        }
    }

    private func stepColor(_ step: MacroStep) -> Color {
        switch step {
        case .key: return Theme.accent
        case .mouse: return Theme.mint
        case .delay: return Theme.tertiary
        }
    }

    private func stepLabel(_ step: MacroStep) -> String {
        switch step {
        case .key(let usage, let down):
            let label = KeyLayout.f108Pro.key(usage: usage)?.label ?? String(format: "0x%02X", usage)
            return "\(label) \(down ? "press" : "release")"
        case .mouse(let button, let down):
            return "Mouse \(button) \(down ? "press" : "release")"
        case .delay:
            return "Wait"
        }
    }

    private func addDelay(_ ms: UInt16, macro: Macro) {
        var updated = macro
        updated.steps.append(.delay(milliseconds: ms))
        model.updateMacro(updated)
    }

    private func addMouse(_ button: UInt8, macro: Macro) {
        var updated = macro
        updated.appendMouseClick(button: button)
        model.updateMacro(updated)
    }

    private func toggleRecording() {
        if recording { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        guard let index = selectedIndex else { return }
        recording = true
        recordingCount = 0
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 { // Esc
                stopRecording()
                return nil
            }
            if event.modifierFlags.contains(.command) { return event }
            if let usage = KeyLayout.usage(forMacKeyCode: event.keyCode) {
                appendRecordedKey(usage, index: index)
            }
            return nil
        }
    }

    private func stopRecording() {
        recording = false
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func appendRecordedKey(_ usage: UInt8, index: Int) {
        guard model.state.macros.indices.contains(index) else { return }
        var macro = model.state.macros[index]
        macro.appendKey(usage)
        model.updateMacro(macro)
        recordingCount += 1
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
