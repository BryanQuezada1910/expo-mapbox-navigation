import Foundation
import ObjectiveC

enum NavigationLocalization {
    private static let lock = NSLock()
    private static var activeLocale = Locale.current
    private static let installOverride: Void = {
        let original = #selector(Bundle.localizedString(forKey:value:table:))
        let replacement = #selector(Bundle.navigationLocalizedString(forKey:value:table:))
        guard let originalMethod = class_getInstanceMethod(Bundle.self, original),
              let replacementMethod = class_getInstanceMethod(Bundle.self, replacement) else { return }
        method_exchangeImplementations(originalMethod, replacementMethod)
    }()

    static func configure(_ locale: Locale) {
        _ = installOverride
        lock.lock()
        activeLocale = locale
        lock.unlock()
    }

    static var locale: Locale {
        lock.lock()
        defer { lock.unlock() }
        return activeLocale
    }
}

extension Bundle {
    @objc func navigationLocalizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        // Only SDK resource bundles follow the navigation locale; host app bundles
        // retain their own localization and AppleLanguages is never changed.
        let mapboxResource = bundleURL.pathComponents.contains {
            let component = $0.lowercased()
            return component.hasPrefix("mapbox") && (component.hasSuffix(".bundle") || component.hasSuffix(".framework"))
        }
        guard mapboxResource else {
            return navigationLocalizedString(forKey: key, value: value, table: tableName)
        }
        let locale = NavigationLocalization.locale
        let language = navigationLanguage(locale)
        let fallbacks = language == "en" ? ["en-US", "en-GB", "en"] : language == "es" ? ["es-MX", "es-419", "es-ES", "es"] : [language]
        let candidates = [locale.identifier, locale.identifier.replacingOccurrences(of: "_", with: "-"), language] + fallbacks
        for candidate in candidates {
            if let path = path(forResource: candidate, ofType: "lproj"), let bundle = Bundle(path: path) {
                return bundle.navigationLocalizedString(forKey: key, value: value, table: tableName)
            }
        }
        return navigationLocalizedString(forKey: key, value: value, table: tableName)
    }
}
