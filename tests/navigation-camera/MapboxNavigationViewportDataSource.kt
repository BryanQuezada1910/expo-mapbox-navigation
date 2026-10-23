package com.mapbox.navigation.ui.maps.camera.data
import com.mapbox.geojson.Point
class MapboxNavigationViewportDataSource {
 var framed = emptyList<Point>()
 fun additionalPointsToFrameForOverview(points: List<Point>) { framed = points.toList() }
 fun evaluate() {}
}
