package expo.modules.mapboxnavigation

import com.mapbox.geojson.Point
import kotlin.math.*

internal object PlannedRouteGeometry {
    private fun offset(point: Point, first: Point, second: Point): Double {
        val scale = cos(point.latitude() * PI / 180.0) * 111195.08
        val ax = (first.longitude() - point.longitude()) * scale
        val ay = (first.latitude() - point.latitude()) * 111195.08
        val bx = (second.longitude() - first.longitude()) * scale
        val by = (second.latitude() - first.latitude()) * 111195.08
        val length = bx * bx + by * by
        val fraction = if (length == 0.0) 0.0 else (-(ax * bx + ay * by) / length).coerceIn(0.0, 1.0)
        return hypot(ax + bx * fraction, ay + by * fraction)
    }
    private fun follows(points: List<Point>, line: List<Point>, tolerance: Double): Boolean {
        var cursor = 0
        var progress = 0.0
        val cumulative = DoubleArray(line.size)
        for (index in 1 until line.size) cumulative[index] = cumulative[index - 1] + offset(line[index], line[index - 1], line[index - 1])
        for (point in points) {
            var best = Double.POSITIVE_INFINITY
            var found = cursor
            for (index in max(0, cursor - 1) until line.size - 1) {
                val distance = offset(point, line[index], line[index + 1])
                if (distance < best) { best = distance; found = index }
            }
            if (best > tolerance) return false
            val first = line[found]
            val second = line[found + 1]
            val scale = cos(point.latitude() * PI / 180.0) * 111195.08
            val dx = (second.longitude() - first.longitude()) * scale
            val dy = (second.latitude() - first.latitude()) * 111195.08
            val length = dx * dx + dy * dy
            val fraction = if (length == 0.0) 0.0 else (((point.longitude() - first.longitude()) * scale * dx + (point.latitude() - first.latitude()) * 111195.08 * dy) / length).coerceIn(0.0, 1.0)
            val projected = cumulative[found] + fraction * (cumulative[found + 1] - cumulative[found])
            if (projected < progress - tolerance) return false
            progress = max(progress, projected)
            cursor = max(cursor, found)
        }
        return true
    }
    fun matches(original: List<Point>, matched: List<Point>, tolerance: Double): Boolean {
        if (original.size < 2 || matched.size < 2) return false
        fun close(first: Point, second: Point) = offset(first, second, second) <= tolerance
        return close(original.first(), matched.first()) && close(original.last(), matched.last()) &&
            follows(original, matched, tolerance) && follows(matched, original, tolerance)
    }
}
