import SwiftUI
import TwentyCore

/// Label chips (color dot + name) with an ordered selection of up to two
/// labels — two selected means the span is split 10 / 10 per block.
///
/// Click rules: an unselected chip becomes the first pick, then the
/// second; a third one starts over with that chip alone. A click on any
/// selected chip always deselects it — selecting never saves; saving is
/// Return, the button, or ⌘1–⌘9.
struct LabelChipsView: View {
    let labels: [TrackLabel]
    @Binding var selection: [String]

    private let columns = [GridItem(.adaptive(minimum: 122), spacing: 6)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(labels) { label in
                chip(for: label)
            }
        }
    }

    private func chip(for label: TrackLabel) -> some View {
        let color = LabelPalette.color(for: label.colorKey)
        let selected = selection.contains(label.id)
        let split = selection.count == 2
        return Button {
            handleTap(label)
        } label: {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(selected && split ? "½ \(label.name)" : label.name)
                    .lineLimit(1)
            }
            .font(.callout)
            .padding(.vertical, 5)
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Capsule().fill(selected ? color.opacity(0.22) : Color.primary.opacity(0.05))
            )
            .overlay(
                Capsule().stroke(selected ? color.opacity(0.85) : .clear, lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(selected
            ? "Klick entfernt dieses Label"
            : "Auswählen · ein zweites Label teilt den Block 10/10")
    }

    private func handleTap(_ label: TrackLabel) {
        if let index = selection.firstIndex(of: label.id) {
            selection.remove(at: index)
            return
        }
        switch selection.count {
        case 0, 1:
            selection.append(label.id)
        default:
            selection = [label.id]
        }
    }
}
