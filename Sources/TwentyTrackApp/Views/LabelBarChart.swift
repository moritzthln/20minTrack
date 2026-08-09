import SwiftUI
import TwentyCore

/// Bottom-aligned bar chart of one label's time per period unit (weekday,
/// month day, or month) with an optional daily-goal reference line.
/// `showValues` puts "2:40" above each bar (week); dense charts use the
/// per-bar tooltip instead. `axisLabel` returning "" leaves a tick blank.
struct LabelBarChart: View {
    let values: [(date: Date, seconds: TimeInterval)]
    let color: Color
    let goalSeconds: TimeInterval?
    var showValues = false
    let axisLabel: (Date, Int) -> String

    private let barAreaHeight: CGFloat = 72

    private var maxSeconds: TimeInterval {
        max(values.map(\.seconds).max() ?? 0, goalSeconds ?? 0, 1)
    }

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: values.count > 12 ? 2 : 8) {
                    ForEach(Array(values.enumerated()), id: \.offset) { _, item in
                        bar(for: item)
                    }
                }
                if let goalSeconds {
                    Rectangle()
                        .fill(color.opacity(0.55))
                        .frame(height: 1)
                        .offset(y: -barAreaHeight * goalSeconds / maxSeconds)
                        .allowsHitTesting(false)
                }
            }
            // Fixed height: without it the ZStack shrinks to the tallest
            // bar and the goal line's offset escapes into the header
            // whenever every bar is below the goal.
            .frame(
                height: barAreaHeight + (showValues ? 16 : 0),
                alignment: .bottom
            )
            HStack(spacing: values.count > 12 ? 2 : 8) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, item in
                    Text(axisLabel(item.date, index))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func bar(for item: (date: Date, seconds: TimeInterval)) -> some View {
        VStack(spacing: 2) {
            if showValues {
                Text(item.seconds > 0 ? Self.hourLabel(item.seconds) : "–")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            RoundedRectangle(cornerRadius: 2.5)
                .fill(item.seconds > 0 ? color : Color.primary.opacity(0.06))
                .frame(height: max(3, barAreaHeight * item.seconds / maxSeconds))
        }
        .frame(maxWidth: .infinity)
        .help(item.seconds > 0
            ? TimeFormatting.wording(seconds: item.seconds)
            : "Keine Zeit")
    }

    /// "2:40" — hours:minutes, compact enough for a bar top.
    static func hourLabel(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        return "\(minutes / 60):\(String(format: "%02d", minutes % 60))"
    }
}
