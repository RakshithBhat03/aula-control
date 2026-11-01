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

    /// Width of the slot bank column; the editor takes the rest of the row.
    private let bankWidth: CGFloat = 252

    var body: some View {
        PageScroll {
            PageHeader(
                eyebrow: "USB-C + macOS",
                title: "Macros",
                subtitle: "Key and mouse sequences stored in the keyboard's 100-slot macro bank. Bind a slot to a key on the Keymap page."
            ) {
                HStack(spacing: 8) {
                    newMacroButton
                    uploadButton
                }
            }

            bankRow {
                if model.state.macros.isEmpty {
                    gettingStarted
                } else if let macro = selectedMacro, let index = selectedIndex {
                    editor(macro: macro, index: index)
                } else {
                    Card(fillHeight: true) {
                        EmptyState(icon: "sidebar.left", title: "No macro selected", message: "Choose a slot from the bank to edit its events.")
                            .frame(maxHeight: .infinity)
                    }
                    .frame(height: 360)
                }
            }
        }
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

    /// The slot bank beside a detail panel. The detail panel sets the row's height and the bank
    /// fills exactly that height, scrolling its slots, so both panels always end on the same line.
    private func bankRow<Detail: View>(@ViewBuilder detail: () -> Detail) -> some View {
        detail()
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.leading, bankWidth + Theme.gutter)
            .overlay(alignment: .topLeading) {
                macroList
                    .frame(width: bankWidth)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
    }

    private func createMacro() {
        model.addMacro()
        selectedID = model.state.macros.last?.id
    }

    /// With an empty bank, creating a macro is the page's primary action; once macros exist,
    /// uploading them takes over and this drops to secondary styling.
    @ViewBuilder
    private var newMacroButton: some View {
        let button = Button(action: createMacro) {
            Label("New macro", systemImage: "plus")
        }
        .disabled(model.state.macros.count >= 100)

        if model.state.macros.isEmpty {
            button.buttonStyle(AccentButtonStyle())
        } else {
            button.buttonStyle(GhostButtonStyle())
        }
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

    /// All 100 slots: filled ones are selectable, free ones show where the next macro lands.
    private var macroList: some View {
        Card(padding: 0, fillHeight: true) {
            VStack(alignment: .leading, spacing: 0) {
                MacroBand {
                    BandTitle("Macro bank", detail: "Slots fill in order from M01.") {
                        ValueChip("\(model.state.macros.count) / 100", color: Theme.secondary)
                    }
                }

                Hairline()

                ScrollView {
                    LazyVStack(spacing: 0) {
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
                        ForEach(min(model.state.macros.count, 100)..<100, id: \.self) { slot in
                            if slot > 0 { Hairline() }
                            FreeSlotRow(slot: slot)
                        }
                    }
                }
                .scrollIndicators(.never)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        }
    }

    // MARK: - Getting started

    /// Empty-bank detail panel: the three steps from nothing to a bound macro, in order.
    private var gettingStarted: some View {
        Card(padding: 0, fillHeight: true) {
            VStack(alignment: .leading, spacing: 0) {
                MacroBand {
                    BandTitle("No macros yet", detail: "A macro replays keys, mouse clicks and delays from any key you bind it to.") {
                        EmptyView()
                    }
                }

                Hairline()

                StepRow(
                    number: 1,
                    title: "Create a macro",
                    detail: "New macro takes the next free slot in the keyboard's bank."
                ) {
                    ValueChip(slotLabel(model.state.macros.count), color: Theme.accent)
                }

                Hairline()

                StepRow(
                    number: 2,
                    title: "Record a sequence",
                    detail: "Record keys captures what you type. Add delays and mouse clicks with Add step."
                ) {
                    HStack(spacing: 6) {
                        Text("Stop with")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.secondary)
                        KeyTag("Esc")
                    }
                }

                Hairline()

                StepRow(
                    number: 3,
                    title: "Bind and upload",
                    detail: "Assign the slot to a key on the Keymap page, then upload the bank over USB-C."
                ) {
                    Button {
                        model.section = .keymap
                    } label: {
                        Label("Open keymap", systemImage: "keyboard")
                    }
                    .buttonStyle(GhostButtonStyle())
                }
            }
        }
    }

    // MARK: - Editor

    private func editor(macro: Macro, index: Int) -> some View {
        Card(padding: 0, fillHeight: true) {
            VStack(alignment: .leading, spacing: 0) {
                MacroBand {
                    editorHeader(macro: macro, index: index)
                }

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
                        TextField("Type text to append", text: $textToAdd)
                            .textFieldStyle(.plain)
                            .font(Theme.bodyFont)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).fill(Theme.field))
                            .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
                            .onSubmit { appendText(to: macro) }
                        Button {
                            appendText(to: macro)
                        } label: {
                            Text("Append text")
                        }
                        .buttonStyle(GhostButtonStyle())
                        .disabled(textToAdd.isEmpty)
                    }
                }
                .padding(Theme.panelInset)

                Spacer(minLength: 0)

                Hairline()

                HStack(alignment: .center, spacing: 16) {
                    Text("Keys bind to a slot number, so deleting a macro shifts every slot after it. Avoid deleting slots that are already assigned.")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        model.section = .keymap
                    } label: {
                        Label("Bind to key", systemImage: "keyboard")
                    }
                    .buttonStyle(GhostButtonStyle())
                }
                .frame(minHeight: 28)
                .padding(.horizontal, Theme.panelInset)
                .padding(.vertical, 12)
            }
        }
    }

    private func appendText(to macro: Macro) {
        guard !textToAdd.isEmpty else { return }
        var updated = macro
        updated.steps.append(contentsOf: Macro.typing(textToAdd).steps)
        model.updateMacro(updated)
        textToAdd = ""
    }

    private func editorHeader(macro: Macro, index: Int) -> some View {
        HStack(spacing: 8) {
            ValueChip(slotLabel(index), color: Theme.accent)
                .padding(.trailing, 4)
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
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)

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
                .frame(height: 24)
                .background(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).fill(Theme.field))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).strokeBorder(Theme.strokeStrong, lineWidth: 1))
            }

            if macro.playMode == .repeatCount {
                Hairline(axis: .vertical)
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

            Hairline(axis: .vertical)
            SpecCell(label: "Events") {
                readout("\(macro.steps.count)")
            }

            Hairline(axis: .vertical)
            SpecCell(label: "Key presses") {
                readout("\(keyPressCount(macro))")
            }

            Hairline(axis: .vertical)
            SpecCell(label: "Length") {
                readout("\(totalDelay(macro)) ms")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func readout(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(Theme.text)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
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
        .frame(height: 32)
        .background(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).fill(Theme.danger.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).strokeBorder(Theme.danger.opacity(0.28), lineWidth: 1))
    }

    /// The event log as a table. Its header stays visible when the macro is empty, so the empty
    /// state reads as a table with no rows yet rather than a separate box.
    private func eventTable(macro: Macro) -> some View {
        VStack(spacing: 0) {
            EventColumns(
                index: Text("#"),
                time: Text("Time (ms)"),
                event: Text("Event"),
                detail: Text("Input")
            ) {
                Color.clear.frame(height: 1)
            }
            .font(Theme.captionFont)
            .foregroundStyle(Theme.tertiary)
            .frame(height: 28)
            .background(Theme.cardRaised)

            Hairline()

            if macro.steps.isEmpty {
                VStack(spacing: 4) {
                    Text("No events")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Text("Press Record keys and type a sequence, or append text below.")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.panelInset * 2)
            } else {
                let offsets = elapsedOffsets(macro.steps)
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
        }
        .background(Theme.field)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
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

/// A panel's top band with a fixed height, so the bank's header hairline lines up with the
/// editor's and the getting-started panel's across the gutter.
private struct MacroBand<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            content
        }
        .frame(height: 36)
        .padding(.horizontal, Theme.panelInset)
        .padding(.vertical, 12)
    }
}

/// Title line (with an optional trailing chip) over one line of detail. Every band title uses
/// the same structure, so titles sit on one baseline across the gutter.
private struct BandTitle<Trailing: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var trailing: Trailing

    init(_ title: String, detail: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.detail = detail
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(Theme.sectionFont)
                    .foregroundStyle(Theme.text)
                Spacer(minLength: 0)
                trailing
            }
            .frame(height: 19)
            Text(detail)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.secondary)
                .lineLimit(1)
        }
    }
}

/// One column of the spec strip: label on top, then a value or control in a fixed-height row,
/// so labels, values and controls line up across cells.
private struct SpecCell<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.tertiary)
            content
                .frame(height: 24, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.panelInset)
        .padding(.vertical, 12)
    }
}

/// One step of the empty-bank walkthrough: number, what to do, and a trailing hint on the
/// panel's trailing inset.
private struct StepRow<Trailing: View>: View {
    let number: Int
    let title: String
    let detail: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            KeyTag("\(number)")
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.text)
                Text(detail)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        // Exactly two bank rows plus their hairline, so step dividers continue the bank's
        // dividers across the gutter and the bank never ends on a half-cut slot.
        .frame(height: MacroBankRow.height * 2 + 1)
        .padding(.horizontal, Theme.panelInset)
    }
}

/// A slot with no macro in it. Not interactive; it shows the bank's capacity and where the next
/// macro lands.
private struct FreeSlotRow: View {
    let slot: Int

    var body: some View {
        HStack(spacing: 10) {
            Text(String(format: "M%02d", slot + 1))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.tertiary.opacity(0.6))
                .frame(width: 30, alignment: .leading)
            Text("Free")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.tertiary.opacity(0.8))
            Spacer(minLength: 0)
        }
        .frame(height: MacroBankRow.height)
        .padding(.horizontal, Theme.panelInset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Slot \(slot + 1), free")
    }
}

private struct MacroBankRow: View {
    let slot: Int
    let macro: Macro
    let isSelected: Bool
    let isRecording: Bool
    let action: () -> Void
    @State private var hovering = false

    static let height: CGFloat = 36

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
                Text(eventCountLabel)
                    .font(Theme.captionFont)
                    .monospacedDigit()
                    .foregroundStyle(Theme.tertiary)
            }
            .frame(height: Self.height)
            .padding(.horizontal, Theme.panelInset)
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

    private var eventCountLabel: String {
        switch macro.steps.count {
        case 0: return "No events"
        case 1: return "1 event"
        case let count: return "\(count) events"
        }
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
        .padding(.horizontal, 12)
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
                .font(Theme.monoFont)
                .foregroundStyle(Theme.tertiary),
            time: Text("\(elapsed)")
                .font(Theme.monoFont)
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
        .font(.system(size: 12))
        .monospacedDigit()
        .frame(minHeight: 30)
        .background(hovering ? Theme.cardRaised.opacity(0.6) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    private var eventLabel: some View {
        HStack(spacing: 6) {
            switch step {
            case .key(_, let down):
                eventGlyph(down ? "arrow.down" : "arrow.up")
                Text(down ? "Key down" : "Key up").foregroundStyle(Theme.text)
            case .mouse(_, let down):
                eventGlyph(down ? "arrow.down" : "arrow.up")
                Text(down ? "Mouse down" : "Mouse up").foregroundStyle(Theme.text)
            case .delay:
                eventGlyph("clock")
                Text("Wait").foregroundStyle(Theme.secondary)
            }
        }
        .lineLimit(1)
    }

    private func eventGlyph(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Theme.tertiary)
            .frame(width: 10)
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
                .font(Theme.monoFont)
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
