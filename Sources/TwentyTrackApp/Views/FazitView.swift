import SwiftUI

/// Free-text daily conclusion for today.
struct FazitView: View {
    let initial: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(loc("Tagesfazit", "Daily review"))
                .font(.headline)
            NotesEditor(text: $text, font: .body)
                .frame(height: 96)
            HStack {
                Spacer()
                Button(loc("Abbrechen", "Cancel"), action: onCancel)
                    .buttonStyle(PillButtonStyle())
                Button(loc("Speichern", "Save")) { onSave(text) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .onAppear { text = initial }
    }
}
