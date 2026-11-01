import SwiftUI

/// A small drawn battery: outline, terminal nub and a fill proportional to the level, followed by
/// the percentage. The fill turns red at 15% and below.
struct BatteryIndicator: View {
    let level: Int

    private var low: Bool { level <= 15 }

    var body: some View {
        HStack(spacing: 5) {
            HStack(spacing: 1) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .strokeBorder(Theme.secondary.opacity(0.8), lineWidth: 1)
                    RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                        .fill(low ? Theme.danger : Theme.text.opacity(0.85))
                        .frame(width: max(1.5, 17 * CGFloat(min(max(level, 0), 100)) / 100))
                        .padding(2)
                }
                .frame(width: 21, height: 10)
                RoundedRectangle(cornerRadius: 0.8, style: .continuous)
                    .fill(Theme.secondary.opacity(0.8))
                    .frame(width: 1.5, height: 4)
            }
            Text("\(level)%")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(low ? Theme.danger : Theme.text.opacity(0.88))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Keyboard battery \(level) percent")
        .help("Keyboard battery")
    }
}
