import SwiftUI
import TwentyCore

/// Optional second label for a span: every 20-minute block is then split
/// 10 / 10 between the two. Shows a menu button while unset and the
/// chosen pairing (with a clear button) once picked.
struct SecondLabelRow: View {
    let labels: [TrackLabel]
    let primaryID: String?
    @Binding var secondID: String?

    private var primary: TrackLabel? {
        labels.first { $0.id == primaryID }
    }

    private var second: TrackLabel? {
        labels.first { $0.id == secondID }
    }

    var body: some View {
        if let primary {
            HStack(spacing: 6) {
                if let second {
                    dot(primary)
                    Text("½ \(primary.name)")
                    Text("·")
                        .foregroundStyle(.secondary)
                    dot(second)
                    Text("½ \(second.name)")
                    Button {
                        secondID = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Zweites Label entfernen")
                } else {
                    Menu("+ Zweites Label (halbe/halbe)") {
                        ForEach(labels.filter { $0.id != primaryID }) { label in
                            Button(label.name) { secondID = label.id }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Teilt jeden 20-Minuten-Block: 10 min je Label")
                }
                Spacer(minLength: 0)
            }
            .font(.caption)
        }
    }

    private func dot(_ label: TrackLabel) -> some View {
        Circle()
            .fill(LabelPalette.color(for: label.colorKey))
            .frame(width: 7, height: 7)
    }
}
