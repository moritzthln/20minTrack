import SwiftUI
import TwentyCore

/// "Benutzt: Chrome 12 min · Slack 5 min (+2)" — the top three apps of a
/// span, one minute minimum. Renders nothing without data.
struct UsageLineView: View {
    let usage: [AppUsageTotal]

    var body: some View {
        let relevant = usage.filter { $0.seconds >= 60 }
        if !relevant.isEmpty {
            Text(line(for: relevant))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private func line(for relevant: [AppUsageTotal]) -> String {
        let top = relevant.prefix(3).map {
            "\($0.name) \(TimeFormatting.wording(seconds: $0.seconds))"
        }
        let more = relevant.count - top.count
        let suffix = more > 0 ? " (+\(more))" : ""
        return "Benutzt: " + top.joined(separator: " · ") + suffix
    }
}
