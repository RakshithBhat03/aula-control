import SwiftUI
import AulaKit

struct KeyboardView: View {
    var layout: KeyLayout = .f108Pro
    var colorFor: (KeyCap) -> AulaRGB?
    var selectedKey: String?
    var mappedKeys: Set<String>
    var showRemapDot: Bool
    var isInteractive: Bool
    var onTap: ((KeyCap) -> Void)?

    init(
        layout: KeyLayout = .f108Pro,
        colorFor: @escaping (KeyCap) -> AulaRGB? = { _ in nil },
        selectedKey: String? = nil,
        mappedKeys: Set<String> = [],
        showRemapDot: Bool = false,
        isInteractive: Bool = true,
        onTap: ((KeyCap) -> Void)? = nil
    ) {
        self.layout = layout
        self.colorFor = colorFor
        self.selectedKey = selectedKey
        self.mappedKeys = mappedKeys
        self.showRemapDot = showRemapDot
        self.isInteractive = isInteractive
        self.onTap = onTap
    }

    var body: some View {
        GeometryReader { geometry in
            let deckPadding: CGFloat = 14
            let unit = (geometry.size.width - deckPadding * 2) / layout.widthUnits
            let gap: CGFloat = max(2, unit * 0.075)

            ZStack(alignment: .topLeading) {
                deck
                ForEach(layout.keys) { key in
                    KeyCapView(
                        key: key,
                        unit: unit,
                        color: colorFor(key),
                        isSelected: selectedKey == key.name,
                        isMapped: mappedKeys.contains(key.name),
                        showMappedDot: showRemapDot
                    ) {
                        onTap?(key)
                    }
                    .frame(
                        width: max(1, key.width * unit - gap),
                        height: max(1, key.height * unit - gap)
                    )
                    .offset(
                        x: deckPadding + key.x * unit + gap / 2,
                        y: deckPadding + key.y * unit + gap / 2
                    )
                    .disabled(!isInteractive)
                }
            }
        }
        .aspectRatio(3.36, contentMode: .fit)
    }

    private var deck: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: 0x1B1F26), Color(hex: 0x0D0F13)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
            LinearGradient(
                colors: [Color.white.opacity(0.045), .clear, Color.black.opacity(0.18)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 5) {
                Circle().fill(Theme.accent).frame(width: 4, height: 4)
                Text("AULA")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(2.2)
                    .foregroundStyle(Theme.secondary.opacity(0.65))
            }
            .padding(.top, 8)
            .padding(.trailing, 14)
        }
    }
}

struct KeyCapView: View {
    let key: KeyCap
    let unit: CGFloat
    let color: AulaRGB?
    let isSelected: Bool
    let isMapped: Bool
    let showMappedDot: Bool
    let action: () -> Void

    @State private var hovering = false

    private var lit: Bool {
        let sum = Int(color?.r ?? 0) + Int(color?.g ?? 0) + Int(color?.b ?? 0)
        return sum > 12
    }

    private var labelColor: Color {
        guard let color, lit else { return Theme.secondary }
        let luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue)
        return luminance > 0.62 ? Color.black.opacity(0.72) : Color.white.opacity(0.94)
    }

    private var fill: LinearGradient {
        if let color, lit {
            return LinearGradient(
                colors: [Color(color).opacity(0.98), Color(color).opacity(0.62)],
                startPoint: .top, endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [Color.white.opacity(hovering ? 0.13 : 0.085), Color.white.opacity(0.028)],
            startPoint: .top, endPoint: .bottom
        )
    }

    var body: some View {
        Button(action: action) {
            GeometryReader { geo in
                let height = geo.size.height
                let width = geo.size.width
                let isWide = width > height * 1.45
                let primary = min(width * 0.28, height * 0.33, isWide ? 15 : 14)
                let secondary = min(width * 0.18, height * 0.19, 11)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: max(4, unit * 0.13), style: .continuous)
                        .fill(fill)
                        .overlay(
                            RoundedRectangle(cornerRadius: max(4, unit * 0.13), style: .continuous)
                                .strokeBorder(
                                    isSelected ? Theme.accent : Color.white.opacity(hovering ? 0.18 : 0.08),
                                    lineWidth: isSelected ? 1.8 : 1
                                )
                        )
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: max(4, unit * 0.13), style: .continuous)
                                .fill(LinearGradient(
                                    colors: [Color.white.opacity(0.10), .clear],
                                    startPoint: .top, endPoint: .center
                                ))
                                .padding(1)
                        }

                    if isWide {
                        HStack(spacing: 4) {
                            if !key.label.isEmpty {
                                Text(key.label)
                                    .font(.system(size: primary, weight: .medium, design: .monospaced))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.55)
                            }
                            if let sub = key.sublabel {
                                Text(sub)
                                    .font(.system(size: secondary, weight: .regular))
                                    .foregroundStyle(labelColor.opacity(0.55))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                            }
                        }
                        .foregroundStyle(labelColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    } else {
                        VStack(alignment: .leading, spacing: 1) {
                            if let sub = key.sublabel, key.name != "space" {
                                Text(sub)
                                    .font(.system(size: secondary, weight: .regular))
                                    .foregroundStyle(labelColor.opacity(0.55))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                            }
                            Spacer(minLength: 0)
                            Text(key.label)
                                .font(.system(size: primary, weight: .medium, design: .monospaced))
                                .foregroundStyle(labelColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                        }
                        .padding(.horizontal, max(3, unit * 0.10))
                        .padding(.vertical, max(2, unit * 0.07))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    }

                    if showMappedDot && isMapped {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: max(4, unit * 0.11), height: max(4, unit * 0.11))
                            .padding(max(4, unit * 0.09))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
                .shadow(
                    color: lit ? Color(color!).opacity(0.32) : Color.black.opacity(0.22),
                    radius: lit ? max(4, unit * 0.22) : 1.5,
                    y: 1.5
                )
                .scaleEffect(hovering ? 0.975 : 1)
                .offset(y: hovering ? 0.5 : 0)
                .animation(.easeOut(duration: 0.12), value: hovering)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("\(key.label) key")
        .help(key.name)
    }
}
