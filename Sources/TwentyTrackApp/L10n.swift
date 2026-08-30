import Foundation

// Lightweight two-language layer: the UI follows the system language.
// German stays the source of truth in code (`loc(de, en)` keeps the
// German literal visible where it is used); everything non-German gets
// English. No .strings bundles — build.sh assembles the app bundle by
// hand, so resource magic would be fragile here.

/// True when the system's preferred language is German.
let germanUI: Bool = Locale.preferredLanguages.first?.lowercased().hasPrefix("de") ?? false

/// Locale for user-facing date formatting.
let l10nLocale = Locale(identifier: germanUI ? "de_DE" : "en_US")

func loc(_ de: String, _ en: String) -> String {
    germanUI ? de : en
}
