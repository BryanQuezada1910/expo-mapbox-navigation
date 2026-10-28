package com.mapbox.navigation.core.mapmatching

import com.mapbox.geojson.Point
import com.mapbox.navigation.base.route.NavigationRoute

class MapMatchingOptions(val coordinates: List<Point>) {
    class Builder {
        private var points = emptyList<Point>()
        fun coordinates(value: List<Point>) = apply { points = value }
        fun waypoints(value: List<Int>) = this
        fun profile(value: String) = this
        fun radiuses(value: List<Double>) = this
        fun annotations(value: List<String>) = this
        fun bannerInstructions(value: Boolean) = this
        fun voiceInstructions(value: Boolean) = this
        fun language(value: String) = this
        fun build() = MapMatchingOptions(points)
    }
}

class MapMatchingFailure
class MapMatchingSuccessfulResult(val navigationRoutes: List<NavigationRoute>)
interface MapMatchingAPICallback {
    fun onCancel()
    fun failure(failure: MapMatchingFailure)
    fun success(result: MapMatchingSuccessfulResult)
}
