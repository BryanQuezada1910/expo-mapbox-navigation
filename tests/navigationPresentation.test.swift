import Foundation

@main
struct NavigationPresentationTests {
    static func main() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let cases = try JSONSerialization.jsonObject(with: data) as! [String: [[String: Any]]]
        for item in cases["guidance"]! {
            let message = plannedGuidanceMessage(status: item["status"] as! String, enabled: item["enabled"] as! Bool,
                finalChunk: item["finalChunk"] as! Bool, instructionType: item["instructionType"] as? String)
            precondition(message == item["message"] as? String, item["name"] as! String)
        }
        for item in cases["speedLimits"]! {
            let presentation = SpeedLimitPresentation.from(speed: item["speed"] as? Double, unit: item["unit"] as! String, failed: item["failed"] as! Bool)
            precondition(presentation.text == item["text"] as! String && presentation.available == item["available"] as! Bool, item["name"] as! String)
            precondition(!presentation.description.isEmpty)
        }
        precondition(!SpeedLimitPresentation.from(speed: .nan, unit: "km/h").available)
        precondition(!SpeedLimitPresentation.from(speed: .infinity, unit: "km/h").available)
        print("15 navigation presentation cases and nonfinite speed values passed")
    }
}
