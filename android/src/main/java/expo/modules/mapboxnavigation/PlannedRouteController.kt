package expo.modules.mapboxnavigation

import com.mapbox.geojson.Point
import com.mapbox.api.directions.v5.DirectionsCriteria
import com.mapbox.geojson.utils.PolylineUtils
import com.mapbox.navigation.base.route.NavigationRoute
import com.mapbox.navigation.core.MapboxNavigation
import com.mapbox.navigation.core.mapmatching.*

@com.mapbox.navigation.base.ExperimentalPreviewMapboxNavigationAPI
internal class PlannedRouteController(
    private val navigation: () -> MapboxNavigation?,
    private val ready: (List<NavigationRoute>, String) -> Unit,
    private val failed: (String, String) -> Unit
) {
    private val cache = linkedMapOf<List<Point>, List<NavigationRoute>>()
    private val pending = mutableSetOf<List<Point>>()
    private val requests = mutableMapOf<List<Point>, Long>()
    private var generation = 0
    private var activeRevision = ""
    private var deliveredRevision: String? = null
    private var activePoints = emptyList<Point>()
    fun reset() {
        generation++
        deliveredRevision = null
        requests.values.forEach { navigation()?.cancelMapMatchingRequest(it) }
        requests.clear(); cache.clear(); pending.clear()
    }
    fun activate(points: List<Point>, next: List<Point>, revision: String, tolerance: Double, language: String) {
        activeRevision = revision
        activePoints = points.toList()
        request(points, revision, tolerance, language, false)
        if (next.size >= 2) request(next, revision, tolerance, language, true)
    }
    private fun request(points: List<Point>, revision: String, tolerance: Double, language: String, prefetch: Boolean) {
        val locale = navigationLocale(language)
        val strings = NavigationStrings(locale)
        val snapshot = points.toList()
        cache[snapshot]?.let { if (!prefetch && revision == activeRevision) deliver(it); return }
        if (snapshot.size !in 2..100) {
            if (!prefetch) failed(strings.invalidRouteChunk, revision)
            return
        }
        // A prefetched request may finish after its window becomes active.
        if (!pending.add(snapshot)) return
        val requestGeneration = generation
        val matchingRadius = maxOf(50.0, tolerance).coerceAtMost(50.0)
        val validationTolerance = maxOf(tolerance * 2.0, 50.0)
        val options = MapMatchingOptions.Builder().coordinates(snapshot)
            .waypoints(listOf(0, snapshot.lastIndex)).profile("driving")
            .radiuses(snapshot.map { matchingRadius })
            .annotations(listOf(DirectionsCriteria.ANNOTATION_MAXSPEED))
            .bannerInstructions(true).voiceInstructions(true).language(language).build()
        val id = navigation()?.requestMapMatching(options, object : MapMatchingAPICallback {
            override fun onCancel() { if (requestGeneration == generation) { pending.remove(snapshot); requests.remove(snapshot) } }
            override fun failure(failure: MapMatchingFailure) {
                if (requestGeneration != generation) return
                pending.remove(snapshot)
                requests.remove(snapshot)
                if (snapshot == activePoints) failed(failure.toString(), activeRevision)
            }
            override fun success(result: MapMatchingSuccessfulResult) {
                if (requestGeneration != generation) return
                pending.remove(snapshot)
                requests.remove(snapshot)
                val routes = result.navigationRoutes.take(1)
                val encoded = routes.firstOrNull()?.directionsRoute?.geometry()
                val geometry = encoded?.let { PolylineUtils.decode(it, 6) } ?: emptyList()
                val validation = PlannedRouteGeometry.validate(snapshot, geometry, validationTolerance)
                if (!validation.matches) {
                    if (snapshot == activePoints) failed(validation.message(validationTolerance, locale), activeRevision)
                    return
                }
                cache[snapshot] = routes
                while (cache.size > 3) cache.remove(cache.keys.first())
                if (snapshot == activePoints) deliver(routes)
            }
        })
        if (id != null) requests[snapshot] = id
        else {
            pending.remove(snapshot)
            if (!prefetch) failed(strings.navigationUnavailable, revision)
        }
    }

    private fun deliver(routes: List<NavigationRoute>) {
        // Prop updates and prefetch changes must not restart the active SDK route.
        if (deliveredRevision == activeRevision) return
        deliveredRevision = activeRevision
        ready(routes, activeRevision)
    }
}
