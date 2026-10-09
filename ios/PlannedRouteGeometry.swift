import CoreLocation

enum PlannedRouteGeometry {
    private static func offset(_ point: CLLocationCoordinate2D, _ first: CLLocationCoordinate2D, _ second: CLLocationCoordinate2D) -> Double {
        let scale = cos(point.latitude * .pi / 180) * 111195.08
        let ax = (first.longitude - point.longitude) * scale
        let ay = (first.latitude - point.latitude) * 111195.08
        let bx = (second.longitude - first.longitude) * scale
        let by = (second.latitude - first.latitude) * 111195.08
        let length = bx * bx + by * by
        let fraction = length == 0 ? 0 : max(0, min(1, -(ax * bx + ay * by) / length))
        return hypot(ax + bx * fraction, ay + by * fraction)
    }
    private static func follows(_ points: [CLLocationCoordinate2D], _ line: [CLLocationCoordinate2D], _ tolerance: Double) -> Bool {
        var cursor = 0
        var progress = 0.0
        var cumulative = [0.0]
        for index in 1..<line.count {
            cumulative.append(cumulative.last! + offset(line[index], line[index - 1], line[index - 1]))
        }
        for point in points {
            var best = Double.infinity
            var found = cursor
            for index in max(0, cursor - 1)..<(line.count - 1) {
                let distance = offset(point, line[index], line[index + 1])
                if distance < best { best = distance; found = index }
            }
            if best > tolerance { return false }
            let first = line[found], second = line[found + 1]
            let scale = cos(point.latitude * .pi / 180) * 111195.08
            let dx = (second.longitude - first.longitude) * scale
            let dy = (second.latitude - first.latitude) * 111195.08
            let length = dx * dx + dy * dy
            let fraction = length == 0 ? 0 : max(0, min(1, ((point.longitude - first.longitude) * scale * dx + (point.latitude - first.latitude) * 111195.08 * dy) / length))
            let projected = cumulative[found] + fraction * (cumulative[found + 1] - cumulative[found])
            if projected < progress - tolerance { return false }
            progress = max(progress, projected)
            cursor = max(cursor, found)
        }
        return true
    }
    static func matches(_ original: [CLLocationCoordinate2D], _ matched: [CLLocationCoordinate2D], tolerance: Double) -> Bool {
        guard original.count >= 2, matched.count >= 2 else { return false }
        return offset(original.first!, matched.first!, matched.first!) <= tolerance &&
            offset(original.last!, matched.last!, matched.last!) <= tolerance &&
            follows(original, matched, tolerance) && follows(matched, original, tolerance)
    }
}
