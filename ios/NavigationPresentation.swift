import Foundation

func isArtificialArrival(finalChunk: Bool, instructionType: String?) -> Bool {
    !finalChunk && instructionType == "arrive"
}

func canPresentNativeManeuver(
    planned: Bool, enabled: Bool, revisionMatches: Bool, onRoute: Bool?,
    finalChunk: Bool, instructionType: String?, hasInstruction: Bool
) -> Bool {
    hasInstruction && (!planned || (
        enabled && revisionMatches && onRoute == true && !isArtificialArrival(finalChunk: finalChunk, instructionType: instructionType)
    ))
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
