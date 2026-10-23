package com.mapbox.navigation.ui.maps.camera
import com.mapbox.navigation.ui.maps.camera.state.*
import com.mapbox.navigation.ui.maps.camera.transition.NavigationCameraTransitionOptions
class NavigationCamera {
 var state = NavigationCameraState.IDLE
 var followingRequests = 0
 val observers = mutableListOf<NavigationCameraStateChangedObserver>()
 fun registerNavigationCameraStateChangeObserver(observer: NavigationCameraStateChangedObserver) { observers.add(observer) }
 fun unregisterNavigationCameraStateChangeObserver(observer: NavigationCameraStateChangedObserver) { observers.remove(observer) }
 fun emit(value: NavigationCameraState) { state = value; observers.toList().forEach { it.onStateChanged(value) } }
 fun requestNavigationCameraToFollowing(stateTransitionOptions: NavigationCameraTransitionOptions) { followingRequests++; emit(NavigationCameraState.FOLLOWING) }
}
