import SwiftUI

/// Multi-line notes field on a soft surface that follows the appearance:
/// slightly lifted from the background with a fine border, instead of
/// TextEditor's default solid black fill in dark mode.
struct NotesEditor: View {
    @Binding var text: String
    var font: Font = .callout
    var placeholder: String = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(font)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 4)
                .padding(.vertical, 5)
            if text.isEmpty, !placeholder.isEmpty {
                Text(placeholder)
                    .font(font)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .allowsHitTesting(false)
            }
        }
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
