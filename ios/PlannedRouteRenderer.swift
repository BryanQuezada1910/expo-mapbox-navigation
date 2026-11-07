import MapboxMaps
import CoreLocation
import Turf
import UIKit

final class PlannedRouteRenderer {
    private static let routeSourceId = "moc-planned-route"
    private static let routeCasingLayerId = "moc-planned-route-casing"
    private static let routeLineLayerId = "moc-planned-route-line"
    private static let endpointsSourceId = "moc-route-endpoints"
    private static let endpointsCircleLayerId = "moc-route-endpoints-circle"
    private static let endpointsSymbolLayerId = "moc-route-endpoints-symbol"

    private weak var previousMap: MapView?
    private var previousCoordinates: [CLLocationCoordinate2D] = []
    private var previousIncludeRouteLine: Bool = true

    func draw(on mapView: MapView, coordinates: [CLLocationCoordinate2D], includeRouteLine: Bool = true) {
        guard let map = mapView.mapboxMap else { return }
        guard coordinates.count >= 2 else {
            clear(from: map)
            previousMap = nil
            previousCoordinates = []
            return
        }

        if !includeRouteLine {
            removeRouteLine(from: map)
        }

        let unchanged = previousMap === mapView
            && previousIncludeRouteLine == includeRouteLine
            && previousCoordinates.count == coordinates.count
            && zip(previousCoordinates, coordinates).allSatisfy {
                $0.0.latitude == $0.1.latitude && $0.0.longitude == $0.1.longitude
            }
        let routeLineReady = !includeRouteLine || (
            map.sourceExists(withId: Self.routeSourceId) && map.layerExists(withId: Self.routeLineLayerId)
        )
        let endpointsReady = map.sourceExists(withId: Self.endpointsSourceId)
            && map.layerExists(withId: Self.endpointsCircleLayerId)
            && map.layerExists(withId: Self.endpointsSymbolLayerId)

        if unchanged && routeLineReady && endpointsReady { return }

        do {
            if includeRouteLine {
                let geometry = Geometry.lineString(LineString(coordinates))
                if map.sourceExists(withId: Self.routeSourceId) {
                    map.updateGeoJSONSource(withId: Self.routeSourceId, geoJSON: .geometry(geometry))
                } else {
                    var source = GeoJSONSource(id: Self.routeSourceId)
                    source.data = .geometry(geometry)
                    try map.addSource(source)
                }
                for (id, width, color) in [
                    (Self.routeCasingLayerId, 9.0, UIColor.white),
                    (Self.routeLineLayerId, 6.0, UIColor(red: 0.20, green: 0.47, blue: 0.96, alpha: 1))
                ] {
                    if !map.layerExists(withId: id) {
                        var layer = LineLayer(id: id, source: Self.routeSourceId)
                        layer.lineColor = .constant(StyleColor(color))
                        layer.lineWidth = .constant(width)
                        layer.lineCap = .constant(.round)
                        layer.lineJoin = .constant(.round)
                        try map.addLayer(layer, layerPosition: map.layerExists(withId: "road-label") ? .below("road-label") : nil)
                    }
                }
            }

            let endpointsCollection = Self.makeEndpointsFeatureCollection(
                origin: coordinates[0],
                destination: coordinates[coordinates.count - 1]
            )
            if map.sourceExists(withId: Self.endpointsSourceId) {
                map.updateGeoJSONSource(withId: Self.endpointsSourceId, geoJSON: .featureCollection(endpointsCollection))
            } else {
                var endpointsSource = GeoJSONSource(id: Self.endpointsSourceId)
                endpointsSource.data = .featureCollection(endpointsCollection)
                try map.addSource(endpointsSource)
            }

            if !map.layerExists(withId: Self.endpointsCircleLayerId) {
                var circleLayer = CircleLayer(id: Self.endpointsCircleLayerId, source: Self.endpointsSourceId)
                circleLayer.circleRadius = .expression(Exp(.get) { "radius" })
                circleLayer.circleColor = .expression(Exp(.get) { "circleColor" })
                circleLayer.circleStrokeColor = .expression(Exp(.get) { "strokeColor" })
                circleLayer.circleStrokeWidth = .expression(Exp(.get) { "strokeWidth" })
                circleLayer.circleEmissiveStrength = .constant(1.0)
                circleLayer.circleOpacity = .constant(1.0)
                circleLayer.circlePitchAlignment = .constant(.viewport)
                try map.addLayer(circleLayer)
            }

            if !map.layerExists(withId: Self.endpointsSymbolLayerId) {
                var symbolLayer = SymbolLayer(id: Self.endpointsSymbolLayerId, source: Self.endpointsSourceId)
                symbolLayer.textField = .expression(Exp(.get) { "label" })
                symbolLayer.textSize = .expression(Exp(.get) { "labelSize" })
                symbolLayer.textColor = .expression(Exp(.get) { "labelColor" })
                symbolLayer.textAllowOverlap = .constant(true)
                symbolLayer.textIgnorePlacement = .constant(true)
                symbolLayer.textAnchor = .constant(.center)
                symbolLayer.textEmissiveStrength = .constant(1.0)
                symbolLayer.textOpacity = .constant(1.0)
                symbolLayer.textPitchAlignment = .constant(.viewport)
                symbolLayer.textRotationAlignment = .constant(.viewport)
                try map.addLayer(symbolLayer)
            }

            previousMap = mapView
            previousCoordinates = coordinates
            previousIncludeRouteLine = includeRouteLine
        } catch {
            NSLog("Planned route rendering failed: %@", error.localizedDescription)
        }
    }

    private func removeRouteLine(from map: MapboxMap) {
        if map.layerExists(withId: Self.routeLineLayerId) {
            try? map.removeLayer(withId: Self.routeLineLayerId)
        }
        if map.layerExists(withId: Self.routeCasingLayerId) {
            try? map.removeLayer(withId: Self.routeCasingLayerId)
        }
        if map.sourceExists(withId: Self.routeSourceId) {
            try? map.removeSource(withId: Self.routeSourceId)
        }
    }

    private func clear(from map: MapboxMap) {
        removeRouteLine(from: map)
        if map.layerExists(withId: Self.endpointsSymbolLayerId) {
            try? map.removeLayer(withId: Self.endpointsSymbolLayerId)
        }
        if map.layerExists(withId: Self.endpointsCircleLayerId) {
            try? map.removeLayer(withId: Self.endpointsCircleLayerId)
        }
        if map.sourceExists(withId: Self.endpointsSourceId) {
            try? map.removeSource(withId: Self.endpointsSourceId)
        }
    }

    private static func makeEndpointsFeatureCollection(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D
    ) -> FeatureCollection {
        var originFeature = Feature(geometry: .point(Point(origin)))
        originFeature.identifier = .string("moc-route-origin")
        originFeature.properties = [
            "kind": .string("origin"),
            "label": .string("A"),
            "circleColor": .string("#05274a"),
            "strokeColor": .string("#ffffff"),
            "strokeWidth": .number(2),
            "radius": .number(18),
            "labelColor": .string("#ffffff"),
            "labelSize": .number(14)
        ]

        var destinationFeature = Feature(geometry: .point(Point(destination)))
        destinationFeature.identifier = .string("moc-route-destination")
        destinationFeature.properties = [
            "kind": .string("destination"),
            "label": .string("B"),
            "circleColor": .string("#d21c31"),
            "strokeColor": .string("#ffffff"),
            "strokeWidth": .number(2),
            "radius": .number(18),
            "labelColor": .string("#ffffff"),
            "labelSize": .number(14)
        ]

        return FeatureCollection(features: [originFeature, destinationFeature])
    }
}
