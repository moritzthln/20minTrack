import SwiftUI
import TwentyCore

/// One day as a horizontal strip of 20-minute slots, colored by label
/// (gray = untracked). Optionally interactive: a click reports the tapped
/// slot's interval. DST days simply have fewer or more slots.
struct DayStripView: View {
    let day: Date
    let entries: [Entry]
    let labelsByID: [String: TrackLabel]
    let calendar: Calendar
    var now: Date?
    var height: CGFloat = 22
    var onTapSlot: ((DateInterval) -> Void)?

    private var slots: [DateInterval] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        let bounds = SlotGrid.boundaries(from: dayStart, to: dayEnd, calendar: calendar)
        guard bounds.count >= 2 else { return [] }
        return zip(bounds, bounds.dropFirst()).map { DateInterval(start: $0, end: $1) }
    }

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            .gesture(
                DragGesture(minimumDistance: 0).onEnded { value in
                    guard let onTapSlot, !slots.isEmpty, geo.size.width > 0 else { return }
                    let fraction = min(max(value.location.x / geo.size.width, 0), 0.999)
                    let index = Int(fraction * CGFloat(slots.count))
                    onTapSlot(slots[index])
                }
            )
        }
        .frame(height: height)
        .onHover { hovering in
            guard onTapSlot != nil else { return }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .help(onTapSlot == nil
            ? ""
            : "Klick auf einen Block: leere Lücke füllen oder Eintrag bearbeiten")
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let count = slots.count
        guard count > 0 else { return }
        let slotWidth = size.width / CGFloat(count)
        for (index, slot) in slots.enumerated() {
            let rect = CGRect(
                x: CGFloat(index) * slotWidth, y: 0,
                width: max(0.5, slotWidth - 1), height: size.height
            )
            context.fill(
                Path(roundedRect: rect, cornerRadius: 1.5),
                with: .color(color(for: slot))
            )
        }
        if let now, let fraction = dayFraction(of: now) {
            let x = fraction * size.width
            let line = CGRect(x: x - 0.75, y: -1, width: 1.5, height: size.height + 2)
            context.fill(Path(line), with: .color(.primary.opacity(0.75)))
        }
    }

    private func color(for slot: DateInterval) -> Color {
        let mid = slot.start.addingTimeInterval(slot.duration / 2)
        guard let entry = entries.first(where: { $0.start <= mid && mid < $0.end }) else {
            return LabelPalette.untracked
        }
        return LabelPalette.color(labelID: entry.labelID, labelsByID: labelsByID)
    }

    private func dayFraction(of date: Date) -> CGFloat? {
        guard let first = slots.first, let last = slots.last else { return nil }
        let total = last.end.timeIntervalSince(first.start)
        guard total > 0 else { return nil }
        let elapsed = date.timeIntervalSince(first.start)
        guard elapsed >= 0, elapsed <= total else { return nil }
        return CGFloat(elapsed / total)
    }
}
