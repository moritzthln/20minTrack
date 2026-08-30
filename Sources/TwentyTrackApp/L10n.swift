import Foundation
import TwentyCore

// Lightweight two-language layer. The UI follows the system language by
// default; a manual override ("de" / "en", stored in UserDefaults) wins.
// German stays the source of truth in code (`loc(de, en)` keeps the
// German literal visible where it is used). No .strings bundles —
// build.sh assembles the app bundle by hand, so resource magic would be
// fragile here.

let languageOverrideKey = TrackLabel.languageOverrideDefaultsKey

/// True when the effective UI language is German.
var germanUI: Bool {
    TrackLabel.effectiveGerman()
}

/// Locale for user-facing date formatting.
var l10nLocale: Locale {
    Locale(identifier: germanUI ? "de_DE" : "en_US")
}

func loc(_ de: String, _ en: String) -> String {
    germanUI ? de : en
}
