import SwiftUI
import AulaKit

/// The list of remapped keys under a board: a title with a count, then one chip per mapping in
/// board order. Shared by the onboard Keymap and Mac remap pages so both read the same way.
struct MappingList: View {
    let title: String
    let keys: [KeyCap]
    let map: KeyRemapMap
    let selectedKey: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                Spacer(minLength: 8)
                if keys.isEmpty {
                    Text("None yet")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.tertiary)
                } else {
                    ValueChip("\(keys.count)")
                }
            }
            if !keys.isEmpty {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 170), spacing: 8, alignment: .leading)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(keys) { key in
                        if let action = map[key.name] {
                            MappingRow(source: key, action: action, isSelected: selectedKey == key.name) {
                                onSelect(key.name)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// One source key and what it now sends. Clicking it selects the key, mirroring a tap on the board.
struct MappingRow: View {
    let source: KeyCap
    let action: KeyAction
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                KeyTag(source.label.isEmpty ? source.name : source.label)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiary)
                Text(action.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.10) : (hovering ? Theme.cardRaised : Theme.field))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent.opacity(0.85) : Theme.stroke, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("\(source.name) sends \(action.displayName)")
        .accessibilityLabel("\(source.label) key sends \(action.displayName)")
    }
}
