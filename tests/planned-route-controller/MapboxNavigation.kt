package com.mapbox.navigation.core

import com.mapbox.navigation.core.mapmatching.MapMatchingAPICallback
import com.mapbox.navigation.core.mapmatching.MapMatchingOptions

class MapboxNavigation {
    val requests = linkedMapOf<Long, Pair<MapMatchingOptions, MapMatchingAPICallback>>()
    val canceled = mutableListOf<Long>()
    fun requestMapMatching(options: MapMatchingOptions, callback: MapMatchingAPICallback): Long {
        val id = requests.size.toLong() + 1
        requests[id] = options to callback
        return id
    }
    fun cancelMapMatchingRequest(id: Long) { canceled.add(id) }
}
