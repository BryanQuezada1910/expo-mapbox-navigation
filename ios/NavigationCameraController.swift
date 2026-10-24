import Combine
import CoreLocation
import MapboxNavigationCore
import MapboxNavigationUIKit
import UIKit

@MainActor
final class NavigationCameraController {
    private weak var controller: NavigationViewController?
    private weak var overviewButton: UIButton?
    private var stateSubscription: AnyCancellable?
    private var plannedViewport: PlannedRouteViewportDataSource?
    private var locale = Locale.current

    func setLocale(_ locale: Locale) {
        self.locale = locale
        if let state = controller?.navigationMapView?.navigationCamera.currentCameraState { updateButtons(state) }
    }

    func attach(to controller: NavigationViewController, planned: Bool, coordinates: [CLLocationCoordinate2D]) {
        if self.controller !== controller {
            self.controller = controller
            // Locate the SDK action without depending on its floating-button order.
            let buttons = controller.floatingButtons ?? []
            overviewButton = buttons.first { button in
                button.allTargets.contains { target in
                    button.actions(forTarget: target, forControlEvent: .touchUpInside)?.contains {
                        $0.localizedCaseInsensitiveContains("overview")
                    } == true
                }
            } ?? buttons.first
            stateSubscription?.cancel()
            stateSubscription = controller.navigationMapView?.navigationCamera.cameraStates.sink { [weak self] in
                self?.updateButtons($0)
            }
        }
        configureViewport(planned: planned, coordinates: coordinates)
        if let state = controller.navigationMapView?.navigationCamera.currentCameraState { updateButtons(state) }
    }

    func configureViewport(planned: Bool, coordinates: [CLLocationCoordinate2D]) {
        guard let map = controller?.navigationMapView else { return }
        let camera = map.navigationCamera
        if planned {
            if let viewport = camera.viewportDataSource as? PlannedRouteViewportDataSource {
                plannedViewport = viewport
                viewport.setCoordinates(coordinates)
            } else {
                let viewport = PlannedRouteViewportDataSource(base: camera.viewportDataSource, mapView: map.mapView, coordinates: coordinates)
                plannedViewport = viewport
                camera.viewportDataSource = viewport
            }
        } else if let viewport = camera.viewportDataSource as? PlannedRouteViewportDataSource {
            camera.viewportDataSource = viewport.base
            plannedViewport = nil
        }
    }

    func setCoordinates(_ coordinates: [CLLocationCoordinate2D]) { plannedViewport?.setCoordinates(coordinates) }

    func restore(_ state: NavigationCameraState?) {
        guard let state = state else { return }
        controller?.navigationMapView?.navigationCamera.update(cameraState: state)
        updateButtons(state)
    }

    func detach() {
        stateSubscription?.cancel()
        stateSubscription = nil
        plannedViewport = nil
        controller = nil
    }

    private func updateButtons(_ state: NavigationCameraState) {
        let following = state == .following
        let strings = NavigationStrings(locale: locale)
        overviewButton?.accessibilityLabel = strings.overviewRoute
        overviewButton?.isHidden = !following
        for button in controller?.navigationView.findViews(subclassOf: ResumeButton.self) ?? [] {
            button.accessibilityLabel = strings.followLocation
            button.isHidden = following
        }
    }
}
