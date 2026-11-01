import SwiftUI
import AulaKit

/// Design tokens for the app. One cool graphite gray family, one amber "LED" accent used only for
/// selection and active state, and muted semantic colors for status. No gradients, no glows.
enum Theme {
    // Surfaces, darkest to lightest.
    static let sidebar = Color(hex: 0x0C0D0F)
    static let background = Color(hex: 0x111214)
    static let field = Color(hex: 0x0E0F11)
    static let card = Color(hex: 0x17181B)
    static let cardRaised = Color(hex: 0x1E1F23)
    static let sidebarElevated = Color(hex: 0x151619)

    static let stroke = Color.white.opacity(0.07)
    static let strokeStrong = Color.white.opacity(0.13)

    static let text = Color(hex: 0xECEDEF)
    static let secondary = Color(hex: 0x9A9DA4)
    static let tertiary = Color(hex: 0x62656C)

    /// The single accent. Reads like an indicator LED on a dark case.
    static let accent = Color(hex: 0xE8A23C)
    static let accentDeep = Color(hex: 0xC4852A)
    static let onAccent = Color(hex: 0x1A1206)

    // Semantic status colors, kept muted so they never compete with the accent.
    static let success = Color(hex: 0x62BE86)
    static let danger = Color(hex: 0xE2665C)
    static let blue = Color(hex: 0x7FA3D9)
    /// Legacy alias; status green.
    static let mint = success

    static let radius: CGFloat = 10
    static let radiusSmall: CGFloat = 6

    // Typography scale.
    static let titleFont = Font.system(size: 22, weight: .semibold)
    static let sectionFont = Font.system(size: 13, weight: .semibold)
    static let bodyFont = Font.system(size: 12.5)
    static let captionFont = Font.system(size: 11.5)
    static let monoFont = Font.system(size: 11.5, weight: .medium, design: .monospaced)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    init(_ rgb: AulaRGB) {
        self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
    }
}

extension AulaRGB {
    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(
            UInt8(max(0, min(1, ns.redComponent)) * 255),
            UInt8(max(0, min(1, ns.greenComponent)) * 255),
            UInt8(max(0, min(1, ns.blueComponent)) * 255)
        )
    }
}

/// A flat panel: surface fill and a hairline border. Use for top-level groups on a page only;
/// nest rows with dividers, not more cards.
struct Card<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
    }
}

/// Section heading inside a panel: sentence-case title, optional detail and trailing accessory.
struct PanelHeader<Trailing: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder var trailing: Trailing

    init(_ title: String, detail: String? = nil, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.detail = detail
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.sectionFont)
                    .foregroundStyle(Theme.text)
                if let detail {
                    Text(detail)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
    }
}

/// Small secondary label. Historically an all-caps eyebrow; now plain sentence case.
struct Eyebrow: View {
    let text: String
    var color: Color = Theme.secondary

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
    }
}

/// A key legend rendered as a tiny keycap, for shortcuts such as `Fn` + `4`.
struct KeyTag: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundStyle(Theme.text)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6)
            .padding(.top, 2)
            .padding(.bottom, 3)
            .frame(minWidth: 20)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.cardRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Theme.strokeStrong, lineWidth: 1)
            )
            .overlay(alignment: .bottom) {
                // Thin darker skirt along the bottom edge so the tag reads as a keycap.
                Rectangle()
                    .fill(Color.black.opacity(0.35))
                    .frame(height: 1.5)
                    .padding(.horizontal, 1)
                    .padding(.bottom, 1)
            }
    }
}

/// A key combination, e.g. `KeyCombo(["Fn", "4"])`.
struct KeyCombo: View {
    let keys: [String]

    init(_ keys: [String]) { self.keys = keys }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(keys.enumerated()), id: \.offset) { index, key in
                if index > 0 {
                    Text("+")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.tertiary)
                }
                KeyTag(key)
            }
        }
    }
}

/// Monospaced value readout, for numbers, hex codes and identifiers.
struct ValueChip: View {
    let text: String
    var color: Color = Theme.text

    init(_ text: String, color: Color = Theme.text) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.field)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
    }
}

/// Page header: title, the transport scope tag (e.g. "USB-C"), one line of context, actions.
struct PageHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: AnyView

    init(eyebrow: String, title: String, subtitle: String, @ViewBuilder trailing: () -> some View = { EmptyView() }) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(title)
                            .font(Theme.titleFont)
                            .foregroundStyle(Theme.text)
                        if !eyebrow.isEmpty {
                            Text(eyebrow)
                                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(Theme.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .strokeBorder(Theme.strokeStrong, lineWidth: 1)
                                )
                                .alignmentGuide(.firstTextBaseline) { $0[.firstTextBaseline] + 3 }
                        }
                    }
                    Text(subtitle)
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.secondary)
                        .frame(maxWidth: 620, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 20)
                trailing
            }
            .padding(.bottom, 18)
            Rectangle()
                .fill(Theme.stroke)
                .frame(height: 1)
        }
    }
}

/// Status indicator: an LED dot (or icon) and a label. Flat, no capsule fill.
struct StatusPill: View {
    let text: String
    let color: Color
    var icon: String?

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
            } else {
                Circle().fill(color).frame(width: 6, height: 6)
            }
            Text(text)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.text.opacity(0.88))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
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

/// Primary action. Solid accent, no gradient.
struct AccentButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .fill(configuration.isPressed ? Theme.accentDeep : Theme.accent)
            )
            .opacity(enabled ? 1 : 0.4)
            .offset(y: configuration.isPressed ? 0.5 : 0)
    }
}

/// Secondary action. Raised neutral surface with a hairline border.
struct GhostButtonStyle: ButtonStyle {
    var danger: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        GhostButtonBody(configuration: configuration, danger: danger)
    }

    private struct GhostButtonBody: View {
        let configuration: ButtonStyle.Configuration
        let danger: Bool
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(danger ? Theme.danger : Theme.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                        .fill(configuration.isPressed ? Theme.card : (hovering ? Color(hex: 0x25262B) : Theme.cardRaised))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                        .strokeBorder(Theme.strokeStrong, lineWidth: 1)
                )
                .opacity(isEnabled ? 1 : 0.4)
                .offset(y: configuration.isPressed ? 0.5 : 0)
                .onHover { hovering = $0 }
        }
    }
}

/// Selectable tile used for grids of modes or action kinds.
struct SelectableTile<Label: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder var label: Label
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            label
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
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
    }
}

struct ToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.text)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(Theme.accent)
        }
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var valueLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                Spacer()
                ValueChip(valueLabel ?? "\(Int(value))")
            }
            Slider(value: $value, in: range, step: step)
                .controlSize(.small)
                .tint(Theme.accent)
        }
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Theme.tertiary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text(message)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

struct Toast: View {
    enum Kind { case success, error, info }

    let kind: Kind
    let message: String

    private var color: Color {
        switch kind {
        case .success: return Theme.success
        case .error: return Theme.danger
        case .info: return Theme.blue
        }
    }

    private var icon: String {
        switch kind {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.cardRaised)
                .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.strokeStrong, lineWidth: 1)
        )
    }
}
