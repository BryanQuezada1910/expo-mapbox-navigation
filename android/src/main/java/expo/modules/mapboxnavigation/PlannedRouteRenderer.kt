package expo.modules.mapboxnavigation

import com.mapbox.geojson.LineString
import com.mapbox.geojson.Point
import com.mapbox.maps.Style
import com.mapbox.maps.extension.style.layers.addLayer
import com.mapbox.maps.extension.style.layers.addLayerBelow
import com.mapbox.maps.extension.style.layers.generated.LineLayer
import com.mapbox.maps.extension.style.sources.addSource
import com.mapbox.maps.extension.style.sources.getSourceAs
import com.mapbox.maps.extension.style.sources.generated.GeoJsonSource

internal object PlannedRouteRenderer {
    private val drawn = java.util.WeakHashMap<Style, List<Point>>()
    private const val sourceId = "moc-planned-route"
    fun draw(style: Style, coordinates: List<Point>) {
        if (coordinates.size < 2) return
        if (drawn[style] == coordinates && style.styleSourceExists(sourceId) && style.styleLayerExists("moc-planned-route-line")) return
        val geometry = LineString.fromLngLats(coordinates)
        val source = style.getSourceAs<GeoJsonSource>(sourceId)
        if (source != null) source.geometry(geometry)
        else style.addSource(GeoJsonSource.Builder(sourceId).geometry(geometry).build())
        for ((id, width, color) in listOf(Triple("moc-planned-route-casing", 9.0, "#ffffff"), Triple("moc-planned-route-line", 6.0, "#3478f6"))) {
            if (!style.styleLayerExists(id)) {
                val layer = LineLayer(id, sourceId).lineWidth(width).lineColor(color)
                if (style.styleLayerExists("road-label")) style.addLayerBelow(layer, "road-label") else style.addLayer(layer)
            }
        }
        drawn[style] = coordinates
    }
}
