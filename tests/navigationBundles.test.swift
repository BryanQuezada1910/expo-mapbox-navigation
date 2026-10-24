import Foundation

@main
struct NavigationBundleTests {
    static func main() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("navigation-localization-\(UUID().uuidString)")
        defer { try? manager.removeItem(at: root) }
        func makeBundle(_ name: String) throws -> Bundle {
            let url = root.appendingPathComponent(name + ".bundle")
            try manager.createDirectory(at: url, withIntermediateDirectories: true)
            let info: [String: Any] = ["CFBundleIdentifier": "tests.\(name)", "CFBundleDevelopmentRegion": "en-US"]
            try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: url.appendingPathComponent("Info.plist"))
            for (locale, value) in [("en-US", "Directions"), ("es-MX", "Indicaciones")] {
                let directory = url.appendingPathComponent(locale + ".lproj")
                try manager.createDirectory(at: directory, withIntermediateDirectories: true)
                try "\"title\" = \"\(value)\";".write(to: directory.appendingPathComponent("Navigation.strings"), atomically: true, encoding: .utf8)
            }
            return Bundle(url: url)!
        }
        let sdk = try makeBundle("MapboxNavigationUIKit")
        let maps = try makeBundle("MapboxMaps")
        let host = try makeBundle("HostApp")
        func title(_ bundle: Bundle) -> String { bundle.localizedString(forKey: "title", value: nil, table: "Navigation") }
        let originalHostTitle = title(host)
        let originalAppleLanguages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
        NavigationLocalization.configure(Locale(identifier: "es-MX"))
        precondition(title(sdk) == "Indicaciones")
        precondition(title(maps) == "Indicaciones")
        precondition(title(host) == originalHostTitle)
        NavigationLocalization.configure(Locale(identifier: "en-US"))
        precondition(title(sdk) == "Directions")
        precondition(title(maps) == "Directions")
        precondition(title(host) == originalHostTitle)
        precondition(UserDefaults.standard.array(forKey: "AppleLanguages") as? [String] == originalAppleLanguages)
        print("Mapbox bundle locale switches passed; host localization and AppleLanguages preserved")
    }
}
