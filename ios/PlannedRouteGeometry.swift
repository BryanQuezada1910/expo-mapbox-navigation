import CoreLocation

enum PlannedRouteGeometry {
    private static let metersPerDegree = 111195.08
    private static let epsilon = 1e-9

    struct Validation {
        let matches: Bool
        let reason: String
        var startOffset = 0.0
        var endOffset = 0.0
        var originalDeviation = 0.0
        var matchedDeviation = 0.0

        func message(tolerance: Double) -> String {
            String(format: "La guía de Mapbox no coincide con la ruta planificada (motivo: %@; inicio: %.1f m; final: %.1f m; desvío original: %.1f m; desvío guía: %.1f m; tolerancia: %.1f m)",
                locale: Locale(identifier: "en_US_POSIX"), reason, startOffset, endOffset, originalDeviation, matchedDeviation, tolerance)
        }
    }

    private struct Interval {
        let start: Double
        let end: Double
        func after(_ minimum: Double) -> Interval? {
            let lower = max(start, minimum)
            return lower <= end + epsilon ? Interval(start: min(lower, end), end: end) : nil
        }
    }

    // The portion of an edge inside the point's tolerance disk.
    private static func interval(_ point: CLLocationCoordinate2D, _ first: CLLocationCoordinate2D, _ second: CLLocationCoordinate2D, _ tolerance: Double) -> Interval? {
        let scale = cos(point.latitude * .pi / 180) * metersPerDegree
        let ax = (first.longitude - point.longitude) * scale
        let ay = (first.latitude - point.latitude) * metersPerDegree
        let dx = (second.longitude - first.longitude) * scale
        let dy = (second.latitude - first.latitude) * metersPerDegree
        let length = dx * dx + dy * dy
        if length == 0 { return hypot(ax, ay) <= tolerance ? Interval(start: 0, end: 1) : nil }
        let projection = -(ax * dx + ay * dy) / length
        let perpendicular = max(0, ax * ax + ay * ay - projection * projection * length)
        let remaining = tolerance * tolerance - perpendicular
        if remaining < -epsilon { return nil }
        let radius = sqrt(max(0, remaining) / length)
        let lower = max(0, projection - radius)
        let upper = min(1, projection + radius)
        return lower <= upper + epsilon ? Interval(start: min(lower, upper), end: upper) : nil
    }

    private static func offset(_ point: CLLocationCoordinate2D, _ first: CLLocationCoordinate2D, _ second: CLLocationCoordinate2D) -> Double {
        let scale = cos(point.latitude * .pi / 180) * metersPerDegree
        let ax = (first.longitude - point.longitude) * scale
        let ay = (first.latitude - point.latitude) * metersPerDegree
        let dx = (second.longitude - first.longitude) * scale
        let dy = (second.latitude - first.latitude) * metersPerDegree
        let length = dx * dx + dy * dy
        let fraction = length == 0 ? 0 : max(0, min(1, -(ax * dx + ay * dy) / length))
        return hypot(ax + dx * fraction, ay + dy * fraction)
    }

    private static func deviation(_ points: [CLLocationCoordinate2D], _ line: [CLLocationCoordinate2D]) -> Double {
        points.map { point in (0..<(line.count - 1)).map { offset(point, line[$0], line[$0 + 1]) }.min()! }.max()!
    }

    // Propagate all reachable intervals instead of choosing a nearest edge.
    // This is the continuous Frechet decision with linear memory.
    private static func follows(_ original: [CLLocationCoordinate2D], _ matched: [CLLocationCoordinate2D], _ tolerance: Double) -> Bool {
        var top = [Interval?](repeating: nil, count: original.count - 1)
        var reachable = true
        for column in 0..<(original.count - 1) {
            let free = interval(matched[0], original[column], original[column + 1], tolerance)
            if reachable, let free = free, free.start <= epsilon { top[column] = Interval(start: 0, end: free.end) }
            reachable = (top[column]?.end ?? -1) >= 1 - epsilon
        }
        var leftBoundaryReachable = true
        var right: Interval?
        for row in 0..<(matched.count - 1) {
            let free = interval(original[0], matched[row], matched[row + 1], tolerance)
            var left: Interval?
            if leftBoundaryReachable, let free = free, free.start <= epsilon { left = Interval(start: 0, end: free.end) }
            leftBoundaryReachable = (left?.end ?? -1) >= 1 - epsilon
            for column in 0..<(original.count - 1) {
                let bottom = top[column]
                let freeRight = interval(original[column + 1], matched[row], matched[row + 1], tolerance)
                let freeTop = interval(matched[row + 1], original[column], original[column + 1], tolerance)
                if bottom != nil { right = freeRight }
                else if let left = left { right = freeRight?.after(left.start) }
                else { right = nil }
                if left != nil { top[column] = freeTop }
                else if let bottom = bottom { top[column] = freeTop?.after(bottom.start) }
                else { top[column] = nil }
                left = right
            }
        }
        return (right?.end ?? -1) >= 1 - epsilon || (top.last.flatMap { $0 }?.end ?? -1) >= 1 - epsilon
    }

    static func validate(_ original: [CLLocationCoordinate2D], _ matched: [CLLocationCoordinate2D], tolerance: Double) -> Validation {
        func valid(_ point: CLLocationCoordinate2D) -> Bool {
            point.latitude.isFinite && point.longitude.isFinite && abs(point.latitude) <= 90 && abs(point.longitude) <= 180
        }
        guard original.count >= 2, matched.count >= 2, tolerance.isFinite, tolerance > 0,
              original.allSatisfy(valid), matched.allSatisfy(valid) else {
            return Validation(matches: false, reason: "invalid_geometry")
        }
        let start = offset(original[0], matched[0], matched[0])
        let end = offset(original.last!, matched.last!, matched.last!)
        let originalDeviation = deviation(original, matched)
        let matchedDeviation = deviation(matched, original)
        let reason: String
        if start > tolerance { reason = "start_offset" }
        else if end > tolerance { reason = "end_offset" }
        else if originalDeviation > tolerance { reason = "original_deviation" }
        else if matchedDeviation > tolerance { reason = "matched_deviation" }
        else if !follows(original, matched, tolerance) { reason = "route_order" }
        else { reason = "matched" }
        return Validation(matches: reason == "matched", reason: reason, startOffset: start, endOffset: end,
            originalDeviation: originalDeviation, matchedDeviation: matchedDeviation)
    }

    static func matches(_ original: [CLLocationCoordinate2D], _ matched: [CLLocationCoordinate2D], tolerance: Double) -> Bool {
        validate(original, matched, tolerance: tolerance).matches
    }
}
