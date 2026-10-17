import CoreLocation
import Foundation

@main
enum PlannedRouteGeometryTests {
    struct Fixture: Decodable {
        let name: String
        let original: [[Double]]
        let matched: [[Double]]
        let expected: Bool
        let tolerance: Double
        let reason: String?
    }
    static func main() throws {
        let path = CommandLine.arguments.dropFirst().first ?? "tests/plannedRouteGeometryCases.json"
        let cases = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        func points(_ values: [[Double]]) -> [CLLocationCoordinate2D] {
            values.map { CLLocationCoordinate2D(latitude: 19 + $0[1] / 111195.08,
                longitude: -99 + $0[0] / (cos(19 * .pi / 180) * 111195.08)) }
        }
        for fixture in cases {
            let result = PlannedRouteGeometry.validate(points(fixture.original), points(fixture.matched), tolerance: fixture.tolerance)
            precondition(result.matches == fixture.expected, fixture.name + ": " + result.message(tolerance: fixture.tolerance))
            if let reason = fixture.reason { precondition(result.reason == reason, fixture.name + ": " + result.reason) }
        }
        print("\(cases.count) iOS geometry regression checks passed")
    }
}
