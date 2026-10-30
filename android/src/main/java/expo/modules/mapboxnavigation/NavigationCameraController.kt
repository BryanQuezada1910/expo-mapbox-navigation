package expo.modules.mapboxnavigation

import android.view.View
import com.mapbox.geojson.Point
import com.mapbox.navigation.ui.maps.camera.NavigationCamera
import com.mapbox.navigation.ui.maps.camera.data.MapboxNavigationViewportDataSource
import com.mapbox.navigation.ui.maps.camera.state.NavigationCameraState
import com.mapbox.navigation.ui.maps.camera.state.NavigationCameraStateChangedObserver
import com.mapbox.navigation.ui.maps.camera.transition.NavigationCameraTransitionOptions

internal class NavigationCameraController(
    private val camera: NavigationCamera,
    private val viewport: MapboxNavigationViewportDataSource,
    private val overviewButton: View,
    private val followButton: View
) {
    private var started = false
    private var waitingForLocationToFollow = false
    private val observer = NavigationCameraStateChangedObserver {
        if (it != NavigationCameraState.IDLE) waitingForLocationToFollow = false
        updateButtons(it)
    }

    fun attach() {
        camera.registerNavigationCameraStateChangeObserver(observer)
        updateButtons(camera.state)
    }

    fun detach() { camera.unregisterNavigationCameraStateChangeObserver(observer) }

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
