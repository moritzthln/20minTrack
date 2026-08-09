import SwiftUI
import TwentyCore

/// "In dieser Zeit benutzt" — a compact, clearly visible list of the apps
/// that were frontmost in the span (top six, one minute minimum), boxed so
/// it reads as its own section of the check-in. Renders nothing without
/// data.
struct UsageLineView: View {
    let usage: [AppUsageTotal]

    private static let maxRows = 6

    var body: some View {
        let relevant = usage.filter { $0.seconds >= 60 }
        if !relevant.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("In dieser Zeit benutzt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(relevant.prefix(Self.maxRows), id: \.bundleID) { total in
                    HStack(spacing: 8) {
                        Text(total.name)
                            .font(.callout)
                            .lineLimit(1)
                        Spacer(minLength: 12)
                        Text(TimeFormatting.wording(seconds: total.seconds))
                            .font(.callout)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                if relevant.count > Self.maxRows {
                    Text("+ \(relevant.count - Self.maxRows) weitere")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05))
            )
        }
    }
}
