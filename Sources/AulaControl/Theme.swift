import SwiftUI
import AulaKit

enum Theme {
    static let background = Color(hex: 0x0A0B0D)
    static let sidebar = Color(hex: 0x0E1014)
    static let sidebarElevated = Color(hex: 0x12151A)
    static let card = Color(hex: 0x15181D)
    static let cardRaised = Color(hex: 0x1A1E25)
    static let field = Color(hex: 0x101216)
    static let stroke = Color.white.opacity(0.065)
    static let strokeStrong = Color.white.opacity(0.12)
    static let text = Color(hex: 0xF3F4F6)
    static let secondary = Color(hex: 0x9AA2AE)
    static let tertiary = Color(hex: 0x6A727E)
    static let accent = Color(hex: 0xF5B544)
    static let accentDeep = Color(hex: 0xD98E1F)
    static let mint = Color(hex: 0x5BD6BE)
    static let blue = Color(hex: 0x6AA8FF)
    static let danger = Color(hex: 0xFF6B5E)
    static let success = Color(hex: 0x6DDE9A)

    static let radius: CGFloat = 18
    static let radiusSmall: CGFloat = 12
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

struct Card<Content: View>: View {
    var padding: CGFloat = 22
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

struct Eyebrow: View {
    let text: String
    var color: Color = Theme.secondary

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(color)
    }
}

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
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: eyebrow, color: Theme.accent.opacity(0.9))
                Text(title)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)
                Text(subtitle)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 20)
            trailing
        }
    }
}

struct StatusPill: View {
    let text: String
    let color: Color
    var icon: String?

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            } else {
                Circle().fill(color).frame(width: 6, height: 6)
            }
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.2)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(color.opacity(0.12)))
        .overlay(Capsule().strokeBorder(color.opacity(0.22), lineWidth: 1))
    }
}

struct AccentButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color(hex: 0x1A1408))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Theme.accent, Theme.accentDeep],
                        startPoint: .top, endPoint: .bottom
                    ))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
            .opacity(enabled ? 1 : 0.42)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    var danger: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(danger ? Theme.danger : Theme.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.10 : 0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
    }
}

struct ToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                Spacer()
                Text(valueLabel ?? "\(Int(value))")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
            }
            Slider(value: $value, in: range, step: step)
                .tint(Theme.accent)
        }
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
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
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.cardRaised)
                .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
    }
}
