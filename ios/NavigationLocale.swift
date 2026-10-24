import Foundation

func navigationLanguage(_ locale: Locale) -> String {
    if #available(iOS 16, macOS 13, *) { return locale.language.languageCode?.identifier ?? "" }
    return locale.languageCode ?? ""
}

func navigationLocale(_ identifier: String?, systemLocale: Locale = .current) -> Locale {
    guard let value = identifier?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty, value.lowercased() != "default" else { return systemLocale }
    let locale = Locale(identifier: value.replacingOccurrences(of: "_", with: "-"))
    return navigationLanguage(locale).isEmpty ? Locale(identifier: "es") : locale
}
