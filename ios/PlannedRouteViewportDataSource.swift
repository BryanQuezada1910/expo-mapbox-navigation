import Combine
import CoreLocation
import MapboxMaps
import MapboxNavigationCore
import UIKit

@MainActor
final class PlannedRouteViewportDataSource: ViewportDataSource {
    let base: ViewportDataSource
    private weak var mapView: MapView?
    private var coordinates: [CLLocationCoordinate2D] = []
    private var viewportPadding: UIEdgeInsets = .zero
    private var cachedSize: CGSize = .zero
    private var cachedPadding: UIEdgeInsets = .zero
    private var cachedOverview: CameraOptions?

    init(base: ViewportDataSource, mapView: MapView, coordinates: [CLLocationCoordinate2D]) {
        self.base = base
        self.mapView = mapView
        self.coordinates = coordinates
    }

    var options: NavigationViewportDataSourceOptions { base.options }
    var currentNavigationCameraOptions: NavigationCameraOptions { framingFullRoute(base.currentNavigationCameraOptions) }
    var navigationCameraOptions: AnyPublisher<NavigationCameraOptions, Never> {
        base.navigationCameraOptions.map { [weak self] in self?.framingFullRoute($0) ?? $0 }.eraseToAnyPublisher()
    }

    func setCoordinates(_ value: [CLLocationCoordinate2D]) {
        coordinates = value
        cachedOverview = nil
    }

    func update(using viewportState: MapboxNavigationCore.ViewportState) {
        viewportPadding = viewportState.viewportPadding
        base.update(using: viewportState)
    }

    private func framingFullRoute(_ original: NavigationCameraOptions) -> NavigationCameraOptions {
        guard coordinates.count >= 2, let mapView = mapView,
              mapView.bounds.width > 0, mapView.bounds.height > 0 else { return original }
        let size = mapView.bounds.size
        let padding = UIEdgeInsets(
            top: min(max(viewportPadding.top, 100), size.height * 0.35),
            left: min(max(viewportPadding.left, 32), size.width * 0.25),
            bottom: min(max(viewportPadding.bottom, 64), size.height * 0.3),
            right: min(max(viewportPadding.right, 32), size.width * 0.25)
        )
        if cachedOverview == nil || cachedSize != size || cachedPadding != padding {
            cachedOverview = try? mapView.mapboxMap.camera(
                for: coordinates,
                camera: CameraOptions(padding: padding, bearing: 0, pitch: 0),
                coordinatesPadding: .zero, maxZoom: 16, offset: nil
            )
            cachedSize = size
            cachedPadding = padding
        }
        var result = original
        if let overview = cachedOverview { result.overviewCamera = overview }
        return result
    }
}
