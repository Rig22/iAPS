import Foundation

/// Eigenes, leichtgewichtiges Lokalisierungssystem für die eigenen Statistik-Erweiterungen.
///
/// Gleiches Muster wie `AIHubL10n`: Bewusst NICHT über Localizable.strings/Crowdin,
/// weil das eigene Stat-Modul nicht in den offiziellen iAPS-Source aufgenommen wird
/// und dort nie übersetzt würde. Offizielle iAPS-Keys (z.B. "Non-completed Loops")
/// werden weiterhin via NSLocalizedString genutzt — hier landen nur Keys, die es
/// upstream nicht gibt.
enum StatL10n {
    static var languageCode: String {
        let preferred = Bundle.main.preferredLocalizations.first ?? "en"
        if tables[preferred] != nil { return preferred }
        let base = String(preferred.prefix(2))
        return tables[base] != nil ? base : "en"
    }

    static func t(_ key: String) -> String {
        tables[languageCode]?[key] ?? tables["en"]?[key] ?? key
    }

    static func t(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), arguments: args)
    }

    // MARK: - Tabellen

    static let tables: [String: [String: String]] = [
        "en": en,
        "de": de,
        "fr": fr,
        "it": it,
        "es": es,
        "nl": nl,
        "pl": pl,
        "sv": sv,
        "da": da,
        "nb": nb,
        "fi": fi,
        "pt": pt,
        "pt-BR": ptBR,
        "ru": ru,
        "tr": tr,
        "uk": uk,
        "sk": sk,
        "hu": hu,
        "ar": ar,
        "he": he,
        "el": el,
        "ca": ca,
        "vi": vi,
        "zh-Hans": zhHans
    ]

    private static let en: [String: String] = [
        "loop.errors": "Loop Errors"
    ]

    private static let de: [String: String] = [
        "loop.errors": "Loop-Fehler"
    ]

    private static let fr: [String: String] = [
        "loop.errors": "Erreurs de boucle"
    ]

    private static let it: [String: String] = [
        "loop.errors": "Errori del ciclo"
    ]

    private static let es: [String: String] = [
        "loop.errors": "Errores de loop"
    ]

    private static let nl: [String: String] = [
        "loop.errors": "Loopfouten"
    ]

    private static let pl: [String: String] = [
        "loop.errors": "Błędy pętli"
    ]

    private static let sv: [String: String] = [
        "loop.errors": "Loopfel"
    ]

    private static let da: [String: String] = [
        "loop.errors": "Loopfejl"
    ]

    private static let nb: [String: String] = [
        "loop.errors": "Loopfeil"
    ]

    private static let fi: [String: String] = [
        "loop.errors": "Loop-virheet"
    ]

    private static let pt: [String: String] = [
        "loop.errors": "Erros de loop"
    ]

    private static let ptBR: [String: String] = [
        "loop.errors": "Erros de loop"
    ]

    private static let ru: [String: String] = [
        "loop.errors": "Ошибки цикла"
    ]

    private static let tr: [String: String] = [
        "loop.errors": "Döngü hataları"
    ]

    private static let uk: [String: String] = [
        "loop.errors": "Помилки петлі"
    ]

    private static let sk: [String: String] = [
        "loop.errors": "Chyby slučky"
    ]

    private static let hu: [String: String] = [
        "loop.errors": "Loop-hibák"
    ]

    private static let ar: [String: String] = [
        "loop.errors": "أخطاء الحلقة"
    ]

    private static let he: [String: String] = [
        "loop.errors": "שגיאות לולאה"
    ]

    private static let el: [String: String] = [
        "loop.errors": "Σφάλματα βρόχου"
    ]

    private static let ca: [String: String] = [
        "loop.errors": "Errors de bucle"
    ]

    private static let vi: [String: String] = [
        "loop.errors": "Lỗi vòng lặp"
    ]

    private static let zhHans: [String: String] = [
        "loop.errors": "循环错误"
    ]
}
