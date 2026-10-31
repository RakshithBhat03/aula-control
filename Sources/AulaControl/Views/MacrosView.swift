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

    private var uploadEnabled: Bool { model.canUseHardware || model.isPreview }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    eyebrow: "USB-C + macOS",
                    title: "Macros",
                    subtitle: "Key and mouse sequences stored in the keyboard's 100-slot macro bank. Bind a slot to a key on the Keymap page."
                ) {
                    HStack(spacing: 8) {
                        Button {
                            model.addMacro()
                            selectedID = model.state.macros.last?.id
                        } label: {
                            Label("New macro", systemImage: "plus")
                        }
                        .buttonStyle(GhostButtonStyle())

                        uploadButton
                    }
                }

                if model.state.macros.isEmpty {
                    Card {
                        VStack(spacing: 4) {
                            EmptyState(
                                icon: "record.circle",
                                title: "No macros",
                                message: "Create a macro, record a few keys, then bind it to a key on the Keymap page."
                            )
                            Button {
                                model.addMacro()
                                selectedID = model.state.macros.last?.id
                            } label: {
                                Label("New macro", systemImage: "plus")
                            }
                            .buttonStyle(AccentButtonStyle())
                            .padding(.bottom, 24)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        macroList
                            .frame(width: 252)
                        if let macro = selectedMacro, let index = selectedIndex {
                            editor(macro: macro, index: index)
                        } else {
                            Card {
                                EmptyState(icon: "sidebar.left", title: "No macro selected", message: "Choose a slot from the bank to edit its events.")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 32)
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

    /// The page's single primary action. With an empty bank, creating a macro is the primary
    /// action instead, so upload drops to secondary styling there.
    @ViewBuilder
    private var uploadButton: some View {
        let button = Button {
            model.uploadMacros()
        } label: {
            Label("Upload macros", systemImage: "arrow.down.to.line")
        }
        .disabled(model.isBusy || !uploadEnabled)
        .help("Write the whole macro bank to the keyboard over USB-C")

        if model.state.macros.isEmpty {
            button.buttonStyle(GhostButtonStyle())
        } else {
            button.buttonStyle(AccentButtonStyle(enabled: uploadEnabled))
        }
    }

    // MARK: - Macro bank

    private var macroList: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Macro bank")
                        .font(Theme.sectionFont)
                        .foregroundStyle(Theme.text)
                    Spacer()
                    ValueChip("\(model.state.macros.count) / 100", color: Theme.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                Hairline()

                ForEach(Array(model.state.macros.enumerated()), id: \.element.id) { index, macro in
                    if index > 0 { Hairline() }
                    MacroBankRow(
                        slot: index,
                        macro: macro,
                        isSelected: selectedID == macro.id,
                        isRecording: recording && selectedID == macro.id
                    ) {
                        selectedID = macro.id
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        }
    }

    // MARK: - Editor

    private func editor(macro: Macro, index: Int) -> some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                editorHeader(macro: macro, index: index)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)

                Hairline()

                specStrip(macro: macro)

                Hairline()

                VStack(alignment: .leading, spacing: 12) {
                    PanelHeader("Event log") {
                        stepToolbar(macro: macro)
                    }

                    if recording {
                        recordingBanner
                    }

                    eventTable(macro: macro)

                    HStack(spacing: 8) {
                        TextField("Type text to append…", text: $textToAdd)
                            .textFieldStyle(.plain)
                            .font(Theme.bodyFont)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).fill(Theme.field))
                            .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
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
                }
                .padding(18)

                Hairline()

                HStack(alignment: .center, spacing: 14) {
                    Text("Keys bind to a slot number, so deleting a macro shifts every slot after it. Avoid deleting slots that are already assigned.")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Button {
                        model.section = .keymap
                    } label: {
                        Label("Bind to key", systemImage: "keyboard")
                    }
                    .buttonStyle(GhostButtonStyle())
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func editorHeader(macro: Macro, index: Int) -> some View {
        HStack(spacing: 12) {
            Text(slotLabel(index))
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1)
                )
                .accessibilityLabel("Slot \(index + 1)")

            TextField("Macro name", text: Binding(
                get: { model.state.macros[safe: index]?.name ?? macro.name },
                set: { name in
                    var updated = macro
                    updated.name = name
                    model.updateMacro(updated)
                }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.text)

            Spacer(minLength: 8)

            Button {
                model.duplicateMacro(macro)
                selectedID = model.state.macros.last?.id
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(GhostButtonStyle())
            .help("Duplicate")
            .accessibilityLabel("Duplicate macro")

            Button {
                model.deleteMacro(macro)
                selectedID = model.state.macros.first?.id
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(GhostButtonStyle(danger: true))
            .help("Delete")
            .accessibilityLabel("Delete macro")
        }
    }

    /// Readout strip: playback controls on the left, derived figures on the right.
    private func specStrip(macro: Macro) -> some View {
        HStack(alignment: .top, spacing: 0) {
            SpecCell(label: "Playback") {
                Menu {
                    ForEach(MacroPlayMode.allCases, id: \.self) { mode in
                        Button(mode.name) {
                            var updated = macro
                            updated.playMode = mode
                            model.updateMacro(updated)
                        }
                    }
                } label: {
                    Text(macro.playMode.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.text)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                // Borderless menus discard label backgrounds, so the field chrome sits outside.
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).fill(Theme.field))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).strokeBorder(Theme.strokeStrong, lineWidth: 1))
            }

            if macro.playMode == .repeatCount {
                VerticalHairline()
                SpecCell(label: "Repeat count") {
                    Stepper(value: Binding(
                        get: { macro.repeatCount },
                        set: { count in
                            var updated = macro
                            updated.repeatCount = count
                            model.updateMacro(updated)
                        }
                    ), in: 1...99) {
                        Text("\(macro.repeatCount)×")
                            .font(Theme.monoFont)
                            .monospacedDigit()
                            .foregroundStyle(Theme.text)
                            .frame(minWidth: 28, alignment: .leading)
                    }
                    .controlSize(.small)
                }
            }

            VerticalHairline()
            SpecCell(label: "Events") {
                readout("\(macro.steps.count)")
            }

            VerticalHairline()
            SpecCell(label: "Key presses") {
                readout("\(keyPressCount(macro))")
            }

            VerticalHairline()
            SpecCell(label: "Length") {
                readout("\(totalDelay(macro)) ms")
            }

            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func readout(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(Theme.text)
            .frame(height: 22, alignment: .leading)
    }

    private func stepToolbar(macro: Macro) -> some View {
        HStack(spacing: 8) {
            Button {
                toggleRecording()
            } label: {
                HStack(spacing: 6) {
                    if recording {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Theme.danger)
                    } else {
                        Circle()
                            .fill(Theme.danger)
                            .frame(width: 7, height: 7)
                    }
                    Text(recording ? "Stop recording" : "Record keys")
                }
            }
            .buttonStyle(GhostButtonStyle())
            .help(recording ? "Stop capturing keystrokes" : "Capture keystrokes into this macro; Esc stops")

            Menu {
                Section("Delay") {
                    Button("50 ms") { addDelay(50, macro: macro) }
                    Button("100 ms") { addDelay(100, macro: macro) }
                    Button("250 ms") { addDelay(250, macro: macro) }
                    Button("500 ms") { addDelay(500, macro: macro) }
                }
                Divider()
                Section("Mouse") {
                    Button("Left click") { addMouse(1, macro: macro) }
                    Button("Right click") { addMouse(2, macro: macro) }
                    Button("Middle click") { addMouse(3, macro: macro) }
                }
            } label: {
                Label("Add step", systemImage: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).fill(Theme.cardRaised))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).strokeBorder(Theme.strokeStrong, lineWidth: 1))

            Button {
                var updated = macro
                updated.steps.removeAll()
                model.updateMacro(updated)
            } label: {
                Text("Clear")
            }
            .buttonStyle(GhostButtonStyle())
            .disabled(macro.steps.isEmpty)
            .help("Remove every event from this macro")
        }
    }

    private var recordingBanner: some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.danger).frame(width: 7, height: 7)
            Text("Recording")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.danger)
            Text("Type on the AULA keyboard.")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.secondary)
            KeyTag("Esc")
            Text("stops.")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.secondary)
            Spacer()
            ValueChip("\(recordingCount) captured", color: Theme.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).fill(Theme.danger.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).strokeBorder(Theme.danger.opacity(0.28), lineWidth: 1))
    }

    @ViewBuilder
    private func eventTable(macro: Macro) -> some View {
        if macro.steps.isEmpty {
            EmptyState(icon: "list.bullet.rectangle", title: "No events", message: "Press Record keys and type a sequence, or append text below.")
                .background(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).fill(Theme.field))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
        } else {
            let offsets = elapsedOffsets(macro.steps)
            VStack(spacing: 0) {
                EventColumns(
                    index: Text("#"),
                    time: Text("t (ms)"),
                    event: Text("Event"),
                    detail: Text("Input")
                ) {
                    Color.clear.frame(height: 1)
                }
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Theme.tertiary)
                .padding(.vertical, 6)
                .background(Theme.cardRaised)

                Hairline()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(macro.steps.enumerated()), id: \.offset) { stepIndex, step in
                            if stepIndex > 0 { Hairline() }
                            EventRow(
                                stepIndex: stepIndex,
                                elapsed: offsets[stepIndex],
                                step: step
                            ) {
                                var updated = macro
                                updated.steps.remove(at: stepIndex)
                                model.updateMacro(updated)
                            }
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
            .background(Theme.field)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
        }
    }

    // MARK: - Derived values

    private func slotLabel(_ index: Int) -> String {
        String(format: "M%02d", index + 1)
    }

    private func keyPressCount(_ macro: Macro) -> Int {
        macro.steps.reduce(0) { count, step in
            if case .key(_, true) = step { return count + 1 }
            return count
        }
    }

    private func totalDelay(_ macro: Macro) -> Int {
        macro.steps.reduce(0) { total, step in
            if case .delay(let ms) = step { return total + Int(ms) }
            return total
        }
    }

    /// Time at which each step fires, counting only the delays before it.
    private func elapsedOffsets(_ steps: [MacroStep]) -> [Int] {
        var offsets: [Int] = []
        offsets.reserveCapacity(steps.count)
        var elapsed = 0
        for step in steps {
            offsets.append(elapsed)
            if case .delay(let ms) = step { elapsed += Int(ms) }
        }
        return offsets
    }

    // MARK: - Mutations

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

// MARK: - Building blocks

private struct Hairline: View {
    var body: some View {
        Rectangle().fill(Theme.stroke).frame(height: 1)
    }
}

private struct VerticalHairline: View {
    var body: some View {
        Rectangle().fill(Theme.stroke).frame(width: 1)
    }
}

/// One column of the spec strip: small label above a value or control.
private struct SpecCell<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.tertiary)
            content
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}

private struct MacroBankRow: View {
    let slot: Int
    let macro: Macro
    let isSelected: Bool
    let isRecording: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(String(format: "M%02d", slot + 1))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.tertiary)
                    .frame(width: 30, alignment: .leading)
                Text(macro.name)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.text : Theme.text.opacity(0.85))
                    .lineLimit(1)
                Spacer(minLength: 6)
                if isRecording {
                    Circle()
                        .fill(Theme.danger)
                        .frame(width: 6, height: 6)
                        .accessibilityLabel("Recording")
                }
                Text(macro.steps.isEmpty ? "empty" : "\(macro.steps.count) ev")
                    .font(.system(size: 10.5, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(Theme.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isSelected ? Theme.accent.opacity(0.08) : (hovering ? Theme.cardRaised : Color.clear))
            .overlay(alignment: .leading) {
                if isSelected {
                    Rectangle()
                        .fill(Theme.accent)
                        .frame(width: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("\(macro.name), slot \(slot + 1), \(macro.steps.count) events")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Shared column grid so the table header and rows line up.
private struct EventColumns<Index: View, Time: View, Event: View, Detail: View, Trailing: View>: View {
    let index: Index
    let time: Time
    let event: Event
    let detail: Detail
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 0) {
            index.frame(width: 44, alignment: .leading)
            time.frame(width: 70, alignment: .trailing)
            Spacer().frame(width: 18)
            event.frame(width: 96, alignment: .leading)
            detail.frame(maxWidth: .infinity, alignment: .leading)
            trailing.frame(width: 22, alignment: .trailing)
        }
        .padding(.horizontal, 10)
    }
}

private struct EventRow: View {
    let stepIndex: Int
    let elapsed: Int
    let step: MacroStep
    let onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        EventColumns(
            index: Text(String(format: "%03d", stepIndex + 1))
                .foregroundStyle(Theme.tertiary),
            time: Text("\(elapsed)")
                .foregroundStyle(Theme.tertiary),
            event: eventLabel,
            detail: detail
        ) {
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(hovering ? Theme.secondary : Theme.tertiary.opacity(0.6))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Remove step")
            .accessibilityLabel("Remove step \(stepIndex + 1)")
        }
        .font(.system(size: 11.5, weight: .regular, design: .monospaced))
        .monospacedDigit()
        .padding(.vertical, 5)
        .background(hovering ? Theme.cardRaised.opacity(0.6) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    private var eventLabel: some View {
        HStack(spacing: 5) {
            switch step {
            case .key(_, let down):
                Text(down ? "↓" : "↑").foregroundStyle(Theme.secondary)
                Text(down ? "key down" : "key up").foregroundStyle(Theme.text)
            case .mouse(_, let down):
                Text(down ? "↓" : "↑").foregroundStyle(Theme.secondary)
                Text(down ? "mouse down" : "mouse up").foregroundStyle(Theme.text)
            case .delay:
                Text("·").foregroundStyle(Theme.tertiary)
                Text("wait").foregroundStyle(Theme.secondary)
            }
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private var detail: some View {
        switch step {
        case .key(let usage, _):
            HStack(spacing: 8) {
                KeyTag(KeyLayout.f108Pro.key(usage: usage)?.label ?? "?")
                Text(String(format: "0x%02X", usage))
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Theme.tertiary)
            }
        case .mouse(let button, _):
            Text(mouseButtonName(button))
                .foregroundStyle(Theme.text)
        case .delay(let ms):
            Text("\(ms) ms")
                .foregroundStyle(Theme.secondary)
        }
    }

    private func mouseButtonName(_ button: UInt8) -> String {
        switch button {
        case 1: return "Left button"
        case 2: return "Right button"
        case 3: return "Middle button"
        default: return "Button \(button)"
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
