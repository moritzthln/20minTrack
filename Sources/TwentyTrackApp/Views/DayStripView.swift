import SwiftUI
import TwentyCore

/// One day as a horizontal strip of 20-minute slots, colored by label
/// (gray = untracked). Interactive when `onSelect` is set: a click
/// reports the tapped slot, a drag reports the whole dragged span —
/// with a live selection highlight and a hover time label. DST days
/// simply have fewer or more slots.
struct DayStripView: View {
    let day: Date
    let entries: [Entry]
    let labelsByID: [String: TrackLabel]
    let calendar: Calendar
    var now: Date?
    var height: CGFloat = 22
    var onSelect: ((DateInterval) -> Void)?

    @State private var dragStartIndex: Int?
    @State private var dragCurrentIndex: Int?
    @State private var hoverIndex: Int?

    private var slots: [DateInterval] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        let bounds = SlotGrid.boundaries(from: dayStart, to: dayEnd, calendar: calendar)
        guard bounds.count >= 2 else { return [] }
        return zip(bounds, bounds.dropFirst()).map { DateInterval(start: $0, end: $1) }
    }

    private var dragRange: ClosedRange<Int>? {
        guard let start = dragStartIndex, let current = dragCurrentIndex else { return nil }
        return min(start, current)...max(start, current)
    }

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            .gesture(selectionGesture(width: geo.size.width))
            .onContinuousHover { phase in
                guard onSelect != nil else { return }
                switch phase {
                case .active(let point):
                    hoverIndex = index(at: point.x, width: geo.size.width)
                case .ended:
                    hoverIndex = nil
                }
            }
            .overlay(alignment: .topLeading) {
                hoverLabel(width: geo.size.width)
            }
        }
        .frame(height: height)
        .onHover { hovering in
            guard onSelect != nil else { return }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .help(onSelect == nil
            ? ""
            : "Klicken oder über einen Bereich ziehen, um ihn einzutragen/zu bearbeiten")
    }

    // MARK: - Selection

    private func selectionGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard onSelect != nil, !slots.isEmpty, width > 0 else { return }
                if dragStartIndex == nil {
                    dragStartIndex = index(at: value.startLocation.x, width: width)
                }
                dragCurrentIndex = index(at: value.location.x, width: width)
            }
            .onEnded { _ in
                defer {
                    dragStartIndex = nil
                    dragCurrentIndex = nil
                }
                guard let range = dragRange, let onSelect, !slots.isEmpty else { return }
                onSelect(DateInterval(
                    start: slots[range.lowerBound].start,
                    end: slots[range.upperBound].end
                ))
            }
    }

    private func index(at x: CGFloat, width: CGFloat) -> Int {
        guard width > 0, !slots.isEmpty else { return 0 }
        let fraction = min(max(x / width, 0), 0.999)
        return Int(fraction * CGFloat(slots.count))
    }

    @ViewBuilder
    private func hoverLabel(width: CGFloat) -> some View {
        if let index = dragRange.map({ $0.upperBound }) ?? hoverIndex,
           slots.indices.contains(index) {
            let slotWidth = width / CGFloat(slots.count)
            let labelWidth: CGFloat = 92
            let x = min(max(CGFloat(index) * slotWidth - labelWidth / 2, 0), width - labelWidth)
            Text(hoverText(fallbackIndex: index))
                .font(.caption2)
                .monospacedDigit()
                .padding(.vertical, 1)
                .padding(.horizontal, 5)
                .background(Capsule().fill(.background.opacity(0.95)))
                .overlay(Capsule().stroke(Color.primary.opacity(0.2), lineWidth: 0.5))
                .frame(width: labelWidth)
                .offset(x: x, y: -16)
                .allowsHitTesting(false)
        }
    }

    private func hoverText(fallbackIndex index: Int) -> String {
        if let range = dragRange, slots.indices.contains(range.lowerBound),
           slots.indices.contains(range.upperBound) {
            return "\(TimeFormatting.clock(slots[range.lowerBound].start, calendar: calendar))–\(TimeFormatting.clock(slots[range.upperBound].end, calendar: calendar))"
        }
        return "\(TimeFormatting.clock(slots[index].start, calendar: calendar))–\(TimeFormatting.clock(slots[index].end, calendar: calendar))"
    }

    // MARK: - Drawing

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
        if let range = dragRange {
            let rect = CGRect(
                x: CGFloat(range.lowerBound) * slotWidth, y: 0,
                width: CGFloat(range.count) * slotWidth - 1, height: size.height
            )
            context.fill(
                Path(roundedRect: rect, cornerRadius: 2),
                with: .color(.white.opacity(0.22))
            )
            context.stroke(
                Path(roundedRect: rect, cornerRadius: 2),
                with: .color(.primary.opacity(0.85)), lineWidth: 1.5
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
