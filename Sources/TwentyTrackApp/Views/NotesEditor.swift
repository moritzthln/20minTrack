import SwiftUI

/// Multi-line notes field on a light "paper" surface with dark text —
/// in light and dark appearance alike, so it reads as one clearly
/// defined writing area instead of a black hole in a dark popover.
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
        // The forced light scheme gives dark text, a dark caret and a
        // matching selection color on the light surface.
        .environment(\.colorScheme, .light)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color(white: 0.975)))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.18), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
