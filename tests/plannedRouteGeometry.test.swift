import CoreLocation

@main
enum PlannedRouteGeometryTests {
    static func main() {
        func point(_ longitude: Double, _ latitude: Double = 19) -> CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        let original = [point(-99), point(-98.99)]
        let dense = [point(-99), point(-98.997), point(-98.994), point(-98.99)]
        precondition(PlannedRouteGeometry.matches(original, dense, tolerance: 25), "different point counts must follow the same road")
        let nearby = dense.map { point($0.longitude, $0.latitude + 0.0001) }
        precondition(PlannedRouteGeometry.matches(original, nearby, tolerance: 25), "small matching offsets are accepted")
        let parallel = dense.map { point($0.longitude, $0.latitude + 0.001) }
        precondition(!PlannedRouteGeometry.matches(original, parallel, tolerance: 25), "a parallel street is rejected")
        precondition(!PlannedRouteGeometry.matches(original, Array(dense.reversed()), tolerance: 25), "reversed direction is rejected")
        let backtracking = [point(-99), point(-98.992), point(-98.997), point(-98.99)]
        precondition(!PlannedRouteGeometry.matches(original, backtracking, tolerance: 25), "backtracking within one edge is rejected")
        let detour = [point(-99), point(-99, 19.002), point(-98.99, 19.002), point(-98.99)]
        precondition(!PlannedRouteGeometry.matches(detour, original, tolerance: 25), "a shortcut with identical endpoints is rejected")
        precondition(!PlannedRouteGeometry.matches([], dense, tolerance: 25), "empty geometry is rejected")
        print("7 native geometry checks passed")
    }
}
