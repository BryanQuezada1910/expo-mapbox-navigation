import Foundation

func plannedGuidanceMessage(status: String, enabled: Bool, onRoute: Bool? = nil, locale: Locale = Locale(identifier: "es")) -> String? {
    let strings = NavigationStrings(locale: locale)
    if onRoute == false || status == "off-route" { return strings.offPlannedRoute }
    if onRoute == true { return nil }
    if status == "unavailable" { return strings.instructionsUnavailable }
    if !enabled { return strings.preparingInstructions }
    return nil
}

func isArtificialArrival(finalChunk: Bool, instructionType: String?) -> Bool {
    !finalChunk && instructionType == "arrive"
}

func plannedContinuationInstruction(roadName: String?, locale: Locale = Locale(identifier: "es")) -> String {
    let strings = NavigationStrings(locale: locale)
    guard let name = roadName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
        return strings.continueOnRoute
    }
    return strings.continueOnRoad(roadName: name)
}

struct SpeedLimitPresentation {
    let text: String
    let description: String
    let available: Bool

    static func from(speed: Double?, unit: String, failed: Bool = false, locale: Locale = Locale(identifier: "es")) -> SpeedLimitPresentation {
        let strings = NavigationStrings(locale: locale)
        if failed {
            return .init(text: strings.speedDataError, description: strings.speedUnavailableDescription, available: false)
        }
        if let speed = speed, speed.isFinite, speed > 0, speed < Double(Int.max) {
            let value = Int(speed.rounded())
            return .init(text: "\(value)\n\(unit)", description: strings.speedLimitDescription(speed: String(value), unit: unit), available: true)
        }
        return .init(text: strings.speedNoData, description: strings.speedNoDataDescription, available: false)
    }
}
