import Foundation

// Simple two-language localization: Italian if the system language is Italian,
// English for every other language.
enum Lang {
    static var isItalian: Bool {
        let code = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return code.hasPrefix("it")
    }
}

/// Returns the Italian string on Italian systems, otherwise the English string.
func tr(_ it: String, _ en: String) -> String {
    Lang.isItalian ? it : en
}
