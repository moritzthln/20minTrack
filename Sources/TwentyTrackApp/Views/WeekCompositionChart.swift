import Charts
import SwiftUI
import TwentyCore

/// One weekday's attributed totals (settled gaps already count as
/// Ablenkung) — the input row of the composition chart.
struct WeekDayComposition: Identifiable {
    let id: Date
    let shortName: String
    let totals: [String: TimeInterval]
    let isAbsent: Bool
}

/// Stacked bars: how each day of the week was composed across labels.
/// Hovering a day shows its exact durations. Depth is only a soft
/// vertical gradient on the segments — heights stay exactly comparable.
struct WeekCompositionChart: View {
    let days: [WeekDayComposition]
    let labels: [TrackLabel]
    let labelsByID: [String: TrackLabel]

    @State private var includeSleep = false
    @State private var hoveredDay: String?

    private struct Segment: Identifiable {
        let id: String
        let day: String
        let labelID: String
        let hours: Double
    }

    /// Stack order = label order (focus at the bottom), archived labels
    /// included so historic time still shows.
    private var segments: [Segment] {
        days.flatMap { day in
            labels.compactMap { label -> Segment? in
                guard includeSleep || label.id != "sleep",
                      let seconds = day.totals[label.id], seconds > 0 else { return nil }
                return Segment(
                    id: "\(day.shortName)-\(label.id)", day: day.shortName,
                    labelID: label.id, hours: seconds / 3600
                )
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(loc("Woche im Überblick", "Week at a glance"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle(loc("Schlaf zeigen", "Show sleep"), isOn: $includeSleep)
                    .toggleStyle(.checkbox)
                    .font(.caption)
            }
            chart
                .frame(height: 170)
        }
    }

    private var chart: some View {
        Chart(segments) { segment in
            BarMark(
                x: .value("Day", segment.day),
                y: .value("Hours", segment.hours),
                width: .ratio(0.62)
            )
            .foregroundStyle(gradient(for: segment.labelID))
            .opacity(hoveredDay == nil || hoveredDay == segment.day ? 1 : 0.45)
        }
        .chartXScale(domain: days.map(\.shortName))
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Color.primary.opacity(0.08))
                AxisValueLabel {
                    if let hours = value.as(Double.self) { Text("\(Int(hours)) h") }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { _ in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let point):
                            hoveredDay = proxy.value(atX: point.x, as: String.self)
                        case .ended:
                            hoveredDay = nil
                        }
                    }
            }
        }
        .overlay(alignment: .topTrailing) { tooltip }
        .animation(.easeOut(duration: 0.15), value: hoveredDay)
        .animation(.easeOut(duration: 0.2), value: includeSleep)
    }

    private func gradient(for labelID: String) -> LinearGradient {
        let base = LabelPalette.color(labelID: labelID, labelsByID: labelsByID)
        return LinearGradient(
            colors: [base.opacity(0.78), base],
            startPoint: .top, endPoint: .bottom
        )
    }

    @ViewBuilder
    private var tooltip: some View {
        if let name = hoveredDay, let day = days.first(where: { $0.shortName == name }) {
            let rows = labels
                .compactMap { label -> (TrackLabel, TimeInterval)? in
                    guard let seconds = day.totals[label.id], seconds > 0 else { return nil }
                    return (label, seconds)
                }
                .sorted { $0.1 > $1.1 }
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.caption.weight(.semibold))
                if day.isAbsent {
                    Text(loc("Abwesend", "Away")).font(.caption2).foregroundStyle(.orange)
                }
                if rows.isEmpty {
                    Text(loc("Nichts erfasst", "Nothing tracked"))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                ForEach(rows, id: \.0.id) { label, seconds in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(LabelPalette.color(for: label.colorKey))
                            .frame(width: 7, height: 7)
                        Text(label.name).font(.caption2)
                        Spacer(minLength: 10)
                        Text(TimeFormatting.wording(seconds: seconds))
                            .font(.caption2).monospacedDigit()
                    }
                }
            }
            .padding(8)
            .frame(width: 190)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .windowBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            .allowsHitTesting(false)
        }
    }
}
