package expo.modules.mapboxnavigation

import android.view.View
import com.mapbox.geojson.Point
import com.mapbox.navigation.ui.maps.camera.NavigationCamera
import com.mapbox.navigation.ui.maps.camera.data.FollowingFrameOptions
import com.mapbox.navigation.ui.maps.camera.data.MapboxNavigationViewportDataSource
import com.mapbox.navigation.ui.maps.camera.state.NavigationCameraState
import com.mapbox.navigation.ui.maps.camera.state.NavigationCameraStateChangedObserver
import com.mapbox.navigation.ui.maps.camera.transition.NavigationCameraTransitionOptions

internal const val DEFAULT_FOLLOWING_MIN_ZOOM = 16.2
internal const val DEFAULT_FOLLOWING_MAX_ZOOM = 17.6
internal const val DEFAULT_FOLLOWING_PITCH = 50.0
internal const val DEFAULT_FOLLOWING_FOCAL_X = 0.5
internal const val DEFAULT_FOLLOWING_FOCAL_Y = 0.85
internal const val DEFAULT_INTERSECTION_DENSITY_MULTIPLIER = 2.5
internal const val DEFAULT_COMPOUND_MANEUVER_DISTANCE = 50.0
internal const val DEFAULT_POST_MANEUVER_FRAMING_DISTANCE = 35.0
internal const val DEFAULT_PITCH_NEAR_MANEUVER_DISTANCE = 70.0

internal class NavigationCameraController(
    private val camera: NavigationCamera,
    private val viewport: MapboxNavigationViewportDataSource,
    private val overviewButton: View,
    private val followButton: View
) {
    private var started = false
    private var waitingForLocationToFollow = false
    private var followingZoom: Double? = null
    private val observer = NavigationCameraStateChangedObserver {
        if (it != NavigationCameraState.IDLE) waitingForLocationToFollow = false
        updateButtons(it)
    }

    fun attach() {
        configureFollowingCamera(followingZoom)
        camera.registerNavigationCameraStateChangeObserver(observer)
        updateButtons(camera.state)
    }

    fun detach() { camera.unregisterNavigationCameraStateChangeObserver(observer) }

    fun configureFollowingCamera(zoom: Double? = followingZoom) {
        followingZoom = zoom
        val validZoom = zoom?.takeIf { it.isFinite() && it > 0.0 }?.coerceIn(10.0, 20.0)
        viewport.options.followingFrameOptions.apply {
            defaultPitch = DEFAULT_FOLLOWING_PITCH
            minZoom = validZoom ?: DEFAULT_FOLLOWING_MIN_ZOOM
            maxZoom = if (validZoom != null) maxOf(validZoom, DEFAULT_FOLLOWING_MAX_ZOOM) else DEFAULT_FOLLOWING_MAX_ZOOM
            focalPoint = FollowingFrameOptions.FocalPoint(DEFAULT_FOLLOWING_FOCAL_X, DEFAULT_FOLLOWING_FOCAL_Y)
            maximizeViewableGeometryWhenPitchZero = false
            intersectionDensityCalculation.enabled = true
            intersectionDensityCalculation.averageDistanceMultiplier = DEFAULT_INTERSECTION_DENSITY_MULTIPLIER
            frameGeometryAfterManeuver.enabled = true
            frameGeometryAfterManeuver.distanceToCoalesceCompoundManeuvers = DEFAULT_COMPOUND_MANEUVER_DISTANCE
            frameGeometryAfterManeuver.distanceToFrameAfterManeuver = DEFAULT_POST_MANEUVER_FRAMING_DISTANCE
            pitchNearManeuvers.enabled = true
            pitchNearManeuvers.triggerDistanceFromManeuver = DEFAULT_PITCH_NEAR_MANEUVER_DISTANCE
        }
        viewport.followingZoomPropertyOverride(null)
        viewport.evaluate()
    }

    fun setPlannedCoordinates(planned: Boolean, coordinates: List<Point>) {
        viewport.additionalPointsToFrameForOverview(if (planned) coordinates else emptyList())
        viewport.evaluate()
    }

    fun routeInstalled() {
        // Internal matching-window changes must preserve overview and manual camera modes.
        if (started) return
        started = true
        if (camera.state == NavigationCameraState.OVERVIEW || camera.state == NavigationCameraState.TRANSITION_TO_OVERVIEW) return
        camera.requestNavigationCameraToFollowing(
            stateTransitionOptions = NavigationCameraTransitionOptions.Builder().maxDuration(0).build()
        )
        waitingForLocationToFollow = camera.state == NavigationCameraState.IDLE
    }

    fun onLocationUpdated() {
        if (!started || !waitingForLocationToFollow) return
        if (camera.state == NavigationCameraState.IDLE) {
            camera.requestNavigationCameraToFollowing(
                stateTransitionOptions = NavigationCameraTransitionOptions.Builder().maxDuration(0).build()
            )
        }
        waitingForLocationToFollow = camera.state == NavigationCameraState.IDLE
    }

    private fun updateButtons(state: NavigationCameraState) {
        val following = state == NavigationCameraState.FOLLOWING || state == NavigationCameraState.TRANSITION_TO_FOLLOWING
        overviewButton.visibility = if (following) View.VISIBLE else View.GONE
        followButton.visibility = if (following) View.GONE else View.VISIBLE
    }
}
