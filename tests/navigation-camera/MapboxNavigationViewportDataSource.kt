package com.mapbox.navigation.ui.maps.camera.data
import com.mapbox.geojson.Point

class FollowingFrameOptions {
 data class FocalPoint(val x: Double, val y: Double)
 class IntersectionDensityCalculation {
  var enabled = true
  var averageDistanceMultiplier = 7.0
 }
 class FrameGeometryAfterManeuver {
  var enabled = true
  var distanceToCoalesceCompoundManeuvers = 150.0
  var distanceToFrameAfterManeuver = 100.0
 }
 class PitchNearManeuvers {
  var enabled = true
  var triggerDistanceFromManeuver = 180.0
 }
 var defaultPitch = 45.0
 var minZoom = 10.5
 var maxZoom = 16.35
 var focalPoint = FocalPoint(0.5, 1.0)
 var maximizeViewableGeometryWhenPitchZero = true
 val intersectionDensityCalculation = IntersectionDensityCalculation()
 val frameGeometryAfterManeuver = FrameGeometryAfterManeuver()
 val pitchNearManeuvers = PitchNearManeuvers()
}

class MapboxNavigationViewportDataSourceOptions {
 val followingFrameOptions = FollowingFrameOptions()
}

class MapboxNavigationViewportDataSource {
 val options = MapboxNavigationViewportDataSourceOptions()
 var framed = emptyList<Point>()
 var zoomOverride: Double? = null
 fun additionalPointsToFrameForOverview(points: List<Point>) { framed = points.toList() }
 fun followingZoomPropertyOverride(value: Double?) { zoomOverride = value }
 fun evaluate() {}
}
