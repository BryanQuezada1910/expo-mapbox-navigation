package expo.modules.mapboxnavigation

import com.mapbox.geojson.Point
import kotlin.math.*

internal object PlannedRouteGeometry {
    private const val metersPerDegree = 111195.08
    private const val epsilon = 1e-9

    internal data class Validation(
        val matches: Boolean,
        val reason: String,
        val startOffset: Double = 0.0,
        val endOffset: Double = 0.0,
        val originalDeviation: Double = 0.0,
        val matchedDeviation: Double = 0.0,
    ) {
        fun message(tolerance: Double): String = String.format(
            java.util.Locale.US,
            "La guía de Mapbox no coincide con la ruta planificada (motivo: %s; inicio: %.1f m; final: %.1f m; desvío original: %.1f m; desvío guía: %.1f m; tolerancia: %.1f m)",
            reason, startOffset, endOffset, originalDeviation, matchedDeviation, tolerance,
        )
    }

    private data class Interval(val start: Double, val end: Double) {
        fun after(minimum: Double): Interval? {
            val lower = max(start, minimum)
            return if (lower <= end + epsilon) Interval(min(lower, end), end) else null
        }
    }

    // The portion of an edge inside the point's tolerance disk.
    private fun interval(point: Point, first: Point, second: Point, tolerance: Double): Interval? {
        val scale = cos(point.latitude() * PI / 180.0) * metersPerDegree
        val ax = (first.longitude() - point.longitude()) * scale
        val ay = (first.latitude() - point.latitude()) * metersPerDegree
        val dx = (second.longitude() - first.longitude()) * scale
        val dy = (second.latitude() - first.latitude()) * metersPerDegree
        val length = dx * dx + dy * dy
        if (length == 0.0) return if (hypot(ax, ay) <= tolerance) Interval(0.0, 1.0) else null
        val projection = -(ax * dx + ay * dy) / length
        val perpendicular = max(0.0, ax * ax + ay * ay - projection * projection * length)
        val remaining = tolerance * tolerance - perpendicular
        if (remaining < -epsilon) return null
        val radius = sqrt(max(0.0, remaining) / length)
        val lower = max(0.0, projection - radius)
        val upper = min(1.0, projection + radius)
        return if (lower <= upper + epsilon) Interval(min(lower, upper), upper) else null
    }

    private fun offset(point: Point, first: Point, second: Point): Double {
        val scale = cos(point.latitude() * PI / 180.0) * metersPerDegree
        val ax = (first.longitude() - point.longitude()) * scale
        val ay = (first.latitude() - point.latitude()) * metersPerDegree
        val dx = (second.longitude() - first.longitude()) * scale
        val dy = (second.latitude() - first.latitude()) * metersPerDegree
        val length = dx * dx + dy * dy
        val fraction = if (length == 0.0) 0.0 else (-(ax * dx + ay * dy) / length).coerceIn(0.0, 1.0)
        return hypot(ax + dx * fraction, ay + dy * fraction)
    }

    private fun deviation(points: List<Point>, line: List<Point>): Double =
        points.maxOf { point -> (0 until line.lastIndex).minOf { offset(point, line[it], line[it + 1]) } }

    // Propagate all reachable intervals in the free-space diagram (continuous
    // Frechet decision). A nearest-edge choice can jump ahead at hairpins.
    // Every point of both polylines must have an ordered traversal within tolerance.
    private fun follows(original: List<Point>, matched: List<Point>, tolerance: Double): Boolean {
        val top = arrayOfNulls<Interval>(original.lastIndex)
        var reachable = true
        for (column in 0 until original.lastIndex) {
            val free = interval(matched.first(), original[column], original[column + 1], tolerance)
            top[column] = if (reachable && free != null && free.start <= epsilon) Interval(0.0, free.end) else null
            reachable = top[column]?.end?.let { it >= 1.0 - epsilon } ?: false
        }
        var leftBoundaryReachable = true
        var right: Interval? = null
        for (row in 0 until matched.lastIndex) {
            val free = interval(original.first(), matched[row], matched[row + 1], tolerance)
            var left = if (leftBoundaryReachable && free != null && free.start <= epsilon) Interval(0.0, free.end) else null
            leftBoundaryReachable = left?.end?.let { it >= 1.0 - epsilon } ?: false
            for (column in 0 until original.lastIndex) {
                val bottom = top[column]
                val freeRight = interval(original[column + 1], matched[row], matched[row + 1], tolerance)
                val freeTop = interval(matched[row + 1], original[column], original[column + 1], tolerance)
                right = if (bottom != null) freeRight else left?.let { freeRight?.after(it.start) }
                top[column] = if (left != null) freeTop else bottom?.let { freeTop?.after(it.start) }
                left = right
            }
        }
        return (right?.end ?: -1.0) >= 1.0 - epsilon || (top.last()?.end ?: -1.0) >= 1.0 - epsilon
    }

    fun validate(original: List<Point>, matched: List<Point>, tolerance: Double): Validation {
        fun valid(point: Point) = point.latitude().isFinite() && point.longitude().isFinite() &&
            abs(point.latitude()) <= 90 && abs(point.longitude()) <= 180
        if (original.size < 2 || matched.size < 2 || !tolerance.isFinite() || tolerance <= 0 ||
            !original.all(::valid) || !matched.all(::valid)) return Validation(false, "invalid_geometry")
        val start = offset(original.first(), matched.first(), matched.first())
        val end = offset(original.last(), matched.last(), matched.last())
        val originalDeviation = deviation(original, matched)
        val matchedDeviation = deviation(matched, original)
        val reason = when {
            start > tolerance -> "start_offset"
            end > tolerance -> "end_offset"
            originalDeviation > tolerance -> "original_deviation"
            matchedDeviation > tolerance -> "matched_deviation"
            !follows(original, matched, tolerance) -> "route_order"
            else -> "matched"
        }
        return Validation(reason == "matched", reason, start, end, originalDeviation, matchedDeviation)
    }

    fun matches(original: List<Point>, matched: List<Point>, tolerance: Double): Boolean =
        validate(original, matched, tolerance).matches
}
