package expo.modules.mapboxnavigation

import com.mapbox.geojson.Point
import com.mapbox.geojson.utils.PolylineUtils
import com.mapbox.navigation.base.route.DirectionsRoute
import com.mapbox.navigation.base.route.NavigationRoute
import com.mapbox.navigation.core.MapboxNavigation
import com.mapbox.navigation.core.mapmatching.MapMatchingFailure
import com.mapbox.navigation.core.mapmatching.MapMatchingSuccessfulResult

fun main() {
    val navigation = MapboxNavigation()
    val ready = mutableListOf<String>()
    val failures = mutableListOf<String>()
    val controller = PlannedRouteController({ navigation }, { _, revision -> ready.add(revision) }, { _, revision -> failures.add(revision) })
    val first = listOf(Point.fromLngLat(-99.0, 19.0), Point.fromLngLat(-98.999, 19.0))
    val next = listOf(first.last(), Point.fromLngLat(-98.998, 19.0))
    fun result(points: List<Point>) = MapMatchingSuccessfulResult(listOf(NavigationRoute(DirectionsRoute(PolylineUtils.encode(points, 6)))))
    fun activate(points: List<Point>, prefetch: List<Point>, revision: String) = controller.activate(points, prefetch, revision, 25.0, "es-MX")

    activate(first, next, "first")
    check(navigation.requests.size == 2)
    navigation.requests[1]!!.second.success(result(first))
    repeat(5) { activate(first, next, "first") }
    check(ready == listOf("first")) { "prop updates must not reinstall the active guide or reset progress" }
    check(navigation.requests.size == 2)

    // Promote the still-pending prefetch; its original callback must install the new active revision.
    activate(next, emptyList(), "second")
    navigation.requests[2]!!.second.success(result(next))
    check(ready == listOf("first", "second"))
    repeat(3) { activate(next, emptyList(), "second") }
    check(ready.size == 2)

    // A genuine new revision (locale/tolerance/retry) can install even with the same geometry.
    activate(next, emptyList(), "second-retry")
    check(ready.last() == "second-retry")
    controller.reset()
    activate(next, emptyList(), "second-retry")
    navigation.requests[3]!!.second.failure(MapMatchingFailure())
    check(failures == listOf("second-retry"))
    activate(next, emptyList(), "recovered")
    val oldCallback = navigation.requests[4]!!.second
    oldCallback.success(result(next))
    check(ready.last() == "recovered")

    controller.reset()
    val previousCount = ready.size
    oldCallback.success(result(next))
    check(ready.size == previousCount) { "reset must reject late callbacks" }
    activate(first, emptyList(), "first")
    navigation.requests[5]!!.second.success(result(first))
    check(ready.size == previousCount + 1) { "a remounted session must install its guide" }
    println("Planned route reuse, prefetch promotion, retries, reset and stale callback cases passed")
}
