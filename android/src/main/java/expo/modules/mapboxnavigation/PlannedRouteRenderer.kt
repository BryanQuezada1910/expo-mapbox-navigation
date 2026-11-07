package expo.modules.mapboxnavigation

import com.mapbox.geojson.Feature
import com.mapbox.geojson.FeatureCollection
import com.mapbox.geojson.LineString
import com.mapbox.geojson.Point
import com.mapbox.maps.Style
import com.mapbox.maps.extension.style.expressions.generated.Expression
import com.mapbox.maps.extension.style.layers.addLayer
import com.mapbox.maps.extension.style.layers.addLayerBelow
import com.mapbox.maps.extension.style.layers.generated.CircleLayer
import com.mapbox.maps.extension.style.layers.generated.LineLayer
import com.mapbox.maps.extension.style.layers.generated.SymbolLayer
import com.mapbox.maps.extension.style.layers.properties.generated.CirclePitchAlignment
import com.mapbox.maps.extension.style.layers.properties.generated.TextAnchor
import com.mapbox.maps.extension.style.layers.properties.generated.TextPitchAlignment
import com.mapbox.maps.extension.style.layers.properties.generated.TextRotationAlignment
import com.mapbox.maps.extension.style.sources.addSource
import com.mapbox.maps.extension.style.sources.getSourceAs
import com.mapbox.maps.extension.style.sources.generated.GeoJsonSource

internal object PlannedRouteRenderer {
    private data class RenderedState(val coordinates: List<Point>, val includeRouteLine: Boolean)

    private val drawn = java.util.WeakHashMap<Style, RenderedState>()
    private const val sourceId = "moc-planned-route"
    private const val casingLayerId = "moc-planned-route-casing"
    private const val lineLayerId = "moc-planned-route-line"
    private const val endpointsSourceId = "moc-route-endpoints"
    private const val endpointsCircleLayerId = "moc-route-endpoints-circle"
    private const val endpointsSymbolLayerId = "moc-route-endpoints-symbol"

    fun draw(style: Style, coordinates: List<Point>, includeRouteLine: Boolean = true) {
        if (coordinates.size < 2) {
            clear(style)
            drawn.remove(style)
            return
        }
        if (!includeRouteLine) {
            removeRouteLine(style)
        }
        val state = RenderedState(coordinates, includeRouteLine)
        val routeLineReady = !includeRouteLine || (
            style.styleSourceExists(sourceId) && style.styleLayerExists(lineLayerId)
        )
        val endpointsReady = style.styleSourceExists(endpointsSourceId)
            && style.styleLayerExists(endpointsCircleLayerId)
            && style.styleLayerExists(endpointsSymbolLayerId)
        if (drawn[style] == state && routeLineReady && endpointsReady) return

        if (includeRouteLine) {
            val geometry = LineString.fromLngLats(coordinates)
            val source = style.getSourceAs<GeoJsonSource>(sourceId)
            if (source != null) source.geometry(geometry)
            else style.addSource(GeoJsonSource.Builder(sourceId).geometry(geometry).build())
            for ((id, width, color) in listOf(
                Triple(casingLayerId, 9.0, "#ffffff"),
                Triple(lineLayerId, 6.0, "#3478f6")
            )) {
                if (!style.styleLayerExists(id)) {
                    val layer = LineLayer(id, sourceId).lineWidth(width).lineColor(color)
                    if (style.styleLayerExists("road-label")) style.addLayerBelow(layer, "road-label") else style.addLayer(layer)
                }
            }
        }

        val endpointsCollection = makeEndpointsFeatureCollection(
            origin = coordinates.first(),
            destination = coordinates.last()
        )
        val endpointsSource = style.getSourceAs<GeoJsonSource>(endpointsSourceId)
        if (endpointsSource != null) endpointsSource.featureCollection(endpointsCollection)
        else style.addSource(GeoJsonSource.Builder(endpointsSourceId).featureCollection(endpointsCollection).build())

        if (!style.styleLayerExists(endpointsCircleLayerId)) {
            val circleLayer = CircleLayer(endpointsCircleLayerId, endpointsSourceId)
                .circleRadius(Expression.get("radius"))
                .circleColor(Expression.get("circleColor"))
                .circleStrokeColor(Expression.get("strokeColor"))
                .circleStrokeWidth(Expression.get("strokeWidth"))
                .circleEmissiveStrength(1.0)
                .circleOpacity(1.0)
                .circlePitchAlignment(CirclePitchAlignment.VIEWPORT)
            style.addLayer(circleLayer)
        }

        if (!style.styleLayerExists(endpointsSymbolLayerId)) {
            val symbolLayer = SymbolLayer(endpointsSymbolLayerId, endpointsSourceId)
                .textField(Expression.get("label"))
                .textSize(Expression.get("labelSize"))
                .textColor(Expression.get("labelColor"))
                .textAllowOverlap(true)
                .textIgnorePlacement(true)
                .textAnchor(TextAnchor.CENTER)
                .textEmissiveStrength(1.0)
                .textOpacity(1.0)
                .textPitchAlignment(TextPitchAlignment.VIEWPORT)
                .textRotationAlignment(TextRotationAlignment.VIEWPORT)
            style.addLayer(symbolLayer)
        }

        drawn[style] = state
    }

    private fun removeRouteLine(style: Style) {
        if (style.styleLayerExists(lineLayerId)) style.removeStyleLayer(lineLayerId)
        if (style.styleLayerExists(casingLayerId)) style.removeStyleLayer(casingLayerId)
        if (style.styleSourceExists(sourceId)) style.removeStyleSource(sourceId)
    }

    private fun clear(style: Style) {
        removeRouteLine(style)
        if (style.styleLayerExists(endpointsSymbolLayerId)) style.removeStyleLayer(endpointsSymbolLayerId)
        if (style.styleLayerExists(endpointsCircleLayerId)) style.removeStyleLayer(endpointsCircleLayerId)
        if (style.styleSourceExists(endpointsSourceId)) style.removeStyleSource(endpointsSourceId)
    }

    private fun makeEndpointsFeatureCollection(origin: Point, destination: Point): FeatureCollection {
        val originFeature = Feature.fromGeometry(origin, null, "moc-route-origin").apply {
            addStringProperty("kind", "origin")
            addStringProperty("label", "A")
            addStringProperty("circleColor", "#05274a")
            addStringProperty("strokeColor", "#ffffff")
            addNumberProperty("strokeWidth", 2.0)
            addNumberProperty("radius", 18.0)
            addStringProperty("labelColor", "#ffffff")
            addNumberProperty("labelSize", 14.0)
        }
        val destinationFeature = Feature.fromGeometry(destination, null, "moc-route-destination").apply {
            addStringProperty("kind", "destination")
            addStringProperty("label", "B")
            addStringProperty("circleColor", "#d21c31")
            addStringProperty("strokeColor", "#ffffff")
            addNumberProperty("strokeWidth", 2.0)
            addNumberProperty("radius", 18.0)
            addStringProperty("labelColor", "#ffffff")
            addNumberProperty("labelSize", 14.0)
        }
        return FeatureCollection.fromFeatures(listOf(originFeature, destinationFeature))
    }
}
