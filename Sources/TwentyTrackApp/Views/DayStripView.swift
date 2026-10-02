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
            : loc("Klicken oder über einen Bereich ziehen, um ihn einzutragen/zu bearbeiten", "Click, or drag across a range, to log or edit it"))
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
            let text = hoverText(fallbackIndex: index)
            let labelWidth = Self.labelWidth(for: text)
            // Centered over the slot (or the dragged span), clamped so it
            // never runs past either end of the strip.
            let center = hoverCenter(index: index, width: width)
            let x = min(max(center - labelWidth / 2, 0), max(0, width - labelWidth))
            Text(text)
                .font(.caption2.weight(.medium))
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: labelWidth, height: 16)
                .background(Capsule().fill(Color(nsColor: .windowBackgroundColor)))
                .overlay(Capsule().stroke(Color.primary.opacity(0.25), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                .offset(x: x, y: -20)
                .allowsHitTesting(false)
        }
    }

    /// "09:00–09:20" or a longer drag span — monospaced digits, so the
    /// width follows the character count.
    private static func labelWidth(for text: String) -> CGFloat {
        CGFloat(text.count) * 6.4 + 14
    }

    private func hoverCenter(index: Int, width: CGFloat) -> CGFloat {
        let slotWidth = width / CGFloat(max(slots.count, 1))
        if let range = dragRange {
            return (CGFloat(range.lowerBound) + CGFloat(range.count) / 2) * slotWidth
        }
        return (CGFloat(index) + 0.5) * slotWidth
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
            // Untracked base, then every overlapping entry proportionally
            // — a block split between two labels shows both colors.
            context.fill(
                Path(roundedRect: rect, cornerRadius: 1.5),
                with: .color(LabelPalette.untracked)
            )
            for entry in entries where entry.end > slot.start && entry.start < slot.end {
                let pieceStart = max(entry.start, slot.start)
                let pieceEnd = min(entry.end, slot.end)
                let from = pieceStart.timeIntervalSince(slot.start) / slot.duration
                let to = pieceEnd.timeIntervalSince(slot.start) / slot.duration
                let pieceRect = CGRect(
                    x: rect.minX + rect.width * from, y: 0,
                    width: max(0.5, rect.width * (to - from)), height: size.height
                )
                context.fill(
                    Path(roundedRect: pieceRect, cornerRadius: 1.5),
                    with: .color(LabelPalette.color(labelID: entry.labelID, labelsByID: labelsByID))
                )
            }
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
        if dragRange == nil, let hoverIndex, slots.indices.contains(hoverIndex) {
            let rect = CGRect(
                x: CGFloat(hoverIndex) * slotWidth - 0.5, y: -1,
                width: slotWidth, height: size.height + 2
            )
            context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(.white.opacity(0.25)))
            context.stroke(Path(roundedRect: rect, cornerRadius: 2), with: .color(.primary.opacity(0.9)), lineWidth: 1.25)
        }
        if let now, let fraction = dayFraction(of: now) {
            drawNowLine(in: &context, x: fraction * size.width, height: size.height)
        }
    }

    /// White line with a dark outline and a small cap: visible on every
    /// label color and on untracked gray, in light and dark mode.
    private func drawNowLine(in context: inout GraphicsContext, x: CGFloat, height: CGFloat) {
        let outline = CGRect(x: x - 1.75, y: -2, width: 3.5, height: height + 4)
        context.fill(Path(roundedRect: outline, cornerRadius: 1.75), with: .color(.black.opacity(0.55)))
        let line = CGRect(x: x - 0.75, y: -1, width: 1.5, height: height + 2)
        context.fill(Path(roundedRect: line, cornerRadius: 0.75), with: .color(.white))
        let cap = CGRect(x: x - 3, y: -4, width: 6, height: 6)
        context.fill(Path(ellipseIn: cap), with: .color(.black.opacity(0.55)))
        context.fill(Path(ellipseIn: cap.insetBy(dx: 1, dy: 1)), with: .color(.white))
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
