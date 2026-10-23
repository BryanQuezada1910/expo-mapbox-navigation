package expo.modules.mapboxnavigation
import android.view.View
import com.mapbox.geojson.Point
import com.mapbox.navigation.ui.maps.camera.NavigationCamera
import com.mapbox.navigation.ui.maps.camera.data.MapboxNavigationViewportDataSource
import com.mapbox.navigation.ui.maps.camera.state.NavigationCameraState
fun main() {
 val camera = NavigationCamera(); val viewport = MapboxNavigationViewportDataSource()
 val overview = View(); val follow = View()
 val controller = NavigationCameraController(camera, viewport, overview, follow)
 fun checkButtons(following: Boolean) {
  check((overview.visibility == View.VISIBLE) == following)
  check((follow.visibility == View.VISIBLE) != following)
 }
 controller.attach(); checkButtons(false)
 controller.routeInstalled(); checkButtons(true)
 val full = (0..200).map { Point.fromLngLat(-99.0 + it / 1000.0, 19.0) }
 controller.setPlannedCoordinates(true, full)
 check(viewport.framed == full && viewport.framed.size == 201)
 camera.emit(NavigationCameraState.TRANSITION_TO_OVERVIEW); checkButtons(false)
 camera.emit(NavigationCameraState.OVERVIEW); checkButtons(false)
 repeat(4) { controller.routeInstalled(); controller.setPlannedCoordinates(true, full) }
 check(camera.followingRequests == 1 && camera.state == NavigationCameraState.OVERVIEW)
 check(viewport.framed.first() == full.first() && viewport.framed.last() == full.last())
 camera.emit(NavigationCameraState.IDLE); checkButtons(false)
 camera.emit(NavigationCameraState.TRANSITION_TO_FOLLOWING); checkButtons(true)
 controller.detach(); check(camera.observers.isEmpty())
 controller.attach(); check(camera.observers.size == 1); checkButtons(true)
 controller.setPlannedCoordinates(false, full); check(viewport.framed.isEmpty())
 controller.detach()
 val delayedCamera = NavigationCamera(); val delayedController = NavigationCameraController(delayedCamera, viewport, View(), View())
 delayedController.attach(); delayedCamera.emit(NavigationCameraState.OVERVIEW); delayedController.routeInstalled()
 check(delayedCamera.state == NavigationCameraState.OVERVIEW && delayedCamera.followingRequests == 0)
 delayedController.detach()
 println("Camera regression PASS: complete trace, exclusive controls, window changes, manual pan and observer cleanup")
}
