import Foundation

@main
struct NavigationPresentationTests {
    static func main() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let cases = try JSONSerialization.jsonObject(with: data) as! [String: [[String: Any]]]
        for item in cases["guidance"]! {
            let visible = canPresentNativeManeuver(
                planned: item["planned"] as! Bool, enabled: item["enabled"] as! Bool,
                revisionMatches: item["revisionMatches"] as! Bool, onRoute: item["onRoute"] as? Bool,
                finalChunk: item["finalChunk"] as! Bool, instructionType: item["instructionType"] as? String,
                hasInstruction: item["hasInstruction"] as! Bool
            )
            precondition(visible == item["showNative"] as! Bool, item["name"] as! String)
            precondition(isArtificialArrival(finalChunk: item["finalChunk"] as! Bool, instructionType: item["instructionType"] as? String) == item["artificialArrival"] as! Bool, item["name"] as! String)
        }
        for item in cases["speedLimits"]! {
            let presentation = SpeedLimitPresentation.from(speed: item["speed"] as? Double, unit: item["unit"] as! String, failed: item["failed"] as! Bool)
            precondition(presentation.text == item["text"] as! String && presentation.available == item["available"] as! Bool, item["name"] as! String)
            precondition(!presentation.description.isEmpty)
        }
        precondition(!SpeedLimitPresentation.from(speed: .nan, unit: "km/h").available)
        precondition(!SpeedLimitPresentation.from(speed: .infinity, unit: "km/h").available)
        precondition(plannedContinuationInstruction(roadName: "MEX 190D", locale: Locale(identifier: "es")) == "Continúa por MEX 190D")
        precondition(plannedContinuationInstruction(roadName: "   ", locale: Locale(identifier: "es")) == "Continúa por la ruta marcada")
        precondition(plannedContinuationInstruction(roadName: "MEX 190D", locale: Locale(identifier: "en")) == "Continue on MEX 190D")
        precondition(plannedContinuationInstruction(roadName: nil, locale: Locale(identifier: "en")) == "Continue along the marked route")
        precondition(shouldPresentPlannedBanner(planned: true, hasNativeManeuver: false, hasPlannedRoute: true))
        precondition(!shouldPresentPlannedBanner(planned: true, hasNativeManeuver: false, hasPlannedRoute: false))
        precondition(resolveEffectiveSpeedLimit(liveSpeed: nil, routeAnnotatedSpeed: 80, lastValidSpeed: 60) == 80)
        precondition(resolveEffectiveSpeedLimit(liveSpeed: nil, routeAnnotatedSpeed: nil, lastValidSpeed: 80) == 80)
        precondition(resolveEffectiveSpeedLimit(liveSpeed: 90, routeAnnotatedSpeed: 80, lastValidSpeed: 60) == 90)
        print("25 navigation presentation cases and nonfinite speed values passed")
    }
}
