import Foundation

@main
struct NavigationLocalizationTests {
    static func main() throws {
        let fixtures = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))) as! [[String: Any]]
        let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))) as! [String: [String: String]]
        for item in fixtures {
            let locale = navigationLocale(item["locale"] as? String, systemLocale: navigationLocale(item["systemLocale"] as? String))
            let expected = catalog[item["language"] as! String]!
            let strings = NavigationStrings(locale: locale)
            precondition(SpeedLimitPresentation.from(speed: nil, unit: "mph", locale: locale).text == expected["speedNoData"])
            precondition(SpeedLimitPresentation.from(speed: nil, unit: "mph", failed: true, locale: locale).text == expected["speedDataError"])
            precondition(SpeedLimitPresentation.from(speed: 70, unit: "mph", locale: locale).description == expected["speedLimitDescription"]!.replacingOccurrences(of: "{speed}", with: "70").replacingOccurrences(of: "{unit}", with: "mph"))
            precondition(strings.overviewRoute == expected["overviewRoute"])
            precondition(strings.followLocation == expected["followLocation"])
            precondition(strings.muteVoice == expected["muteVoice"])
            precondition(strings.unmuteVoice == expected["unmuteVoice"])
            precondition(strings.cancelNavigation == expected["cancelNavigation"])
            precondition(strings.defaultMarkerLetter == expected["defaultMarkerLetter"])
            precondition(strings.invalidRouteGeometry == expected["invalidRouteGeometry"])
        }
        print("12 Swift locale variants and localized navigation states passed")
    }
}
