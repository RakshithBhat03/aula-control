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
            let gap: CGFloat = max(1.5, unit * 0.06)

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

    /// The case plate. Flat and slightly darker than the page so the caps sit on it.
    private var deck: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(hex: 0x0A0B0C))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
    }
}

/// One keycap, drawn as a physical cap: a darker skirt with an inset top face. A lit key carries
/// its LED color on the face; an unlit key is plain graphite.
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

    private var luminance: Double {
        guard let color else { return 0 }
        return 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue
    }

    private var labelColor: Color {
        guard lit else { return Theme.text.opacity(0.78) }
        return luminance > 0.6 ? Color.black.opacity(0.78) : Color.white.opacity(0.95)
    }

    private var faceColor: Color {
        if let color, lit { return Color(color) }
        return hovering ? Color(hex: 0x2A2C31) : Color(hex: 0x222327)
    }

    private var skirtColor: Color {
        if let color, lit {
            return Color(.sRGB, red: color.red * 0.55, green: color.green * 0.55, blue: color.blue * 0.55, opacity: 1)
        }
        return Color(hex: 0x17181B)
    }

    var body: some View {
        Button(action: action) {
            GeometryReader { geo in
                let height = geo.size.height
                let width = geo.size.width
                let isWide = width > height * 1.45
                let primary = min(width * 0.26, height * 0.30, isWide ? 13 : 12.5)
                let secondary = min(width * 0.17, height * 0.18, 10)
                let radius = max(3, unit * 0.10)
                let side = max(1.5, unit * 0.06)
                let bottom = max(2.5, unit * 0.12)

                ZStack(alignment: .topLeading) {
                    // Skirt.
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(skirtColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.45), lineWidth: 1)
                        )

                    // Top face.
                    RoundedRectangle(cornerRadius: max(2, radius - 1), style: .continuous)
                        .fill(faceColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: max(2, radius - 1), style: .continuous)
                                .strokeBorder(Color.white.opacity(lit ? 0.18 : 0.06), lineWidth: 0.75)
                        )
                        .padding(.leading, side)
                        .padding(.trailing, side)
                        .padding(.top, max(1, side * 0.6))
                        .padding(.bottom, bottom)

                    legends(isWide: isWide, primary: primary, secondary: secondary, side: side, bottom: bottom)

                    if showMappedDot && isMapped {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(Theme.accent)
                            .frame(width: max(4, unit * 0.1), height: max(4, unit * 0.1))
                            .padding(.top, max(4, unit * 0.1))
                            .padding(.trailing, max(4, unit * 0.1) + side)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }

                    if isSelected {
                        RoundedRectangle(cornerRadius: radius + 1.5, style: .continuous)
                            .strokeBorder(Theme.accent, lineWidth: 1.75)
                            .padding(-2)
                    }
                }
                .offset(y: hovering ? 0.5 : 0)
                .animation(.easeOut(duration: 0.1), value: hovering)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("\(key.label) key")
        .help(key.name)
    }

    @ViewBuilder
    private func legends(isWide: Bool, primary: CGFloat, secondary: CGFloat, side: CGFloat, bottom: CGFloat) -> some View {
        if isWide {
            HStack(spacing: 4) {
                if !key.label.isEmpty {
                    Text(key.label)
                        .font(.system(size: primary, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
                if let sub = key.sublabel {
                    Text(sub)
                        .font(.system(size: secondary))
                        .foregroundStyle(labelColor.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .foregroundStyle(labelColor)
            .padding(.horizontal, side + 3)
            .padding(.bottom, bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if let sub = key.sublabel, key.name != "space" {
                    Text(sub)
                        .font(.system(size: secondary))
                        .foregroundStyle(labelColor.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                Spacer(minLength: 0)
                Text(key.label)
                    .font(.system(size: primary, weight: .medium))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            .padding(.leading, side + max(2.5, unit * 0.09))
            .padding(.trailing, side + 2)
            .padding(.top, max(2, unit * 0.07))
            .padding(.bottom, bottom + max(1.5, unit * 0.05))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}
