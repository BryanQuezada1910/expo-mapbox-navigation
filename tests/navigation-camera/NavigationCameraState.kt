package com.mapbox.navigation.ui.maps.camera.state
enum class NavigationCameraState { IDLE, FOLLOWING, TRANSITION_TO_FOLLOWING, OVERVIEW, TRANSITION_TO_OVERVIEW }
fun interface NavigationCameraStateChangedObserver { fun onStateChanged(state: NavigationCameraState) }
