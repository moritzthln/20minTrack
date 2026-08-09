import SwiftUI
import TwentyCore

/// Selectable label chips (color dot + name), wrapping into columns.
struct LabelChipsView: View {
    let labels: [TrackLabel]
    @Binding var selectedID: String?

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
        let selected = selectedID == label.id
        return Button {
            selectedID = label.id
        } label: {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label.name).lineLimit(1)
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
    }
}
