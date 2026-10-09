import MapboxMaps
import CoreLocation
import Turf

final class PlannedRouteRenderer {
    private weak var previousMap: MapView?
    private var previousCoordinates: [CLLocationCoordinate2D] = []
    func draw(on mapView: MapView, coordinates: [CLLocationCoordinate2D]) {
        guard coordinates.count >= 2 else { return }
        guard let map = mapView.mapboxMap else { return }
        let unchanged = previousMap === mapView && previousCoordinates.count == coordinates.count &&
            zip(previousCoordinates, coordinates).allSatisfy { $0.0.latitude == $0.1.latitude && $0.0.longitude == $0.1.longitude }
        if unchanged && map.sourceExists(withId: "moc-planned-route") && map.layerExists(withId: "moc-planned-route-line") { return }
        let geometry = Geometry.lineString(LineString(coordinates))
        do {
            if map.sourceExists(withId: "moc-planned-route") {
                map.updateGeoJSONSource(withId: "moc-planned-route", geoJSON: .geometry(geometry))
            } else {
                var source = GeoJSONSource(id: "moc-planned-route")
                source.data = .geometry(geometry)
                try map.addSource(source)
            }
            for (id, width, color) in [("moc-planned-route-casing", 9.0, UIColor.white), ("moc-planned-route-line", 6.0, UIColor(red: 0.20, green: 0.47, blue: 0.96, alpha: 1))] {
                if !map.layerExists(withId: id) {
                    var layer = LineLayer(id: id, source: "moc-planned-route")
                    layer.lineColor = .constant(StyleColor(color))
                    layer.lineWidth = .constant(width)
                    layer.lineCap = .constant(.round)
                    layer.lineJoin = .constant(.round)
                    try map.addLayer(layer, layerPosition: map.layerExists(withId: "road-label") ? .below("road-label") : nil)
                }
            }
            previousMap = mapView
            previousCoordinates = coordinates
        } catch {
            NSLog("Planned route rendering failed: %@", error.localizedDescription)
        }
    }
}
