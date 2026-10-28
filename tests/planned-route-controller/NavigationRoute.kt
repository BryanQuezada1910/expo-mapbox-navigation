package com.mapbox.navigation.base.route

class DirectionsRoute(private val encoded: String) {
    fun geometry(): String = encoded
}

class NavigationRoute(val directionsRoute: DirectionsRoute)
