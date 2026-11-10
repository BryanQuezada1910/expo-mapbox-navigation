import Combine
import CoreLocation
import MapboxNavigationCore
import MapboxNavigationUIKit
import UIKit

@MainActor
final class NavigationCameraController {
    static let defaultFollowingMinZoom: Double = 16.2
    static let defaultFollowingMaxZoom: Double = 17.6
    static let defaultFollowingPitch: Double = 50.0
    static let defaultIntersectionMultiplier: Double = 2.5
    static let defaultCompoundManeuverDistance: Double = 50.0
    static let defaultPostManeuverFramingDistance: Double = 35.0
    static let defaultPitchNearManeuverDistance: Double = 70.0

    private weak var controller: NavigationViewController?
    private weak var overviewButton: UIButton?
    private var stateSubscription: AnyCancellable?
    private var plannedViewport: PlannedRouteViewportDataSource?
    private var locale = Locale.current
    private var followingZoom: Double?

    func setLocale(_ locale: Locale) {
        self.locale = locale
        if let state = controller?.navigationMapView?.navigationCamera.currentCameraState { updateButtons(state) }
    }

    func setFollowingZoom(_ zoom: Double?) {
        followingZoom = zoom
        guard let map = controller?.navigationMapView else { return }
        let camera = map.navigationCamera
        if let viewport = camera.viewportDataSource as? PlannedRouteViewportDataSource {
            applyFollowingOptions(to: viewport.base)
        } else {
            applyFollowingOptions(to: camera.viewportDataSource)
        }
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
                applyFollowingOptions(to: viewport.base)
                plannedViewport = viewport
                viewport.setCoordinates(coordinates)
            } else {
                applyFollowingOptions(to: camera.viewportDataSource)
                let viewport = PlannedRouteViewportDataSource(base: camera.viewportDataSource, mapView: map.mapView, coordinates: coordinates)
                plannedViewport = viewport
                camera.viewportDataSource = viewport
            }
        } else if let viewport = camera.viewportDataSource as? PlannedRouteViewportDataSource {
            applyFollowingOptions(to: viewport.base)
            camera.viewportDataSource = viewport.base
            plannedViewport = nil
        } else {
            applyFollowingOptions(to: camera.viewportDataSource)
        }
    }

    private func applyFollowingOptions(to dataSource: ViewportDataSource) {
        guard let mobileDataSource = dataSource as? MobileViewportDataSource else { return }
        var following = mobileDataSource.options.followingCameraOptions
        if let zoom = followingZoom, zoom.isFinite, zoom > 0 {
            let clamped = min(max(zoom, 10.0), 20.0)
            following.zoomRange = clamped...max(clamped, Self.defaultFollowingMaxZoom)
        } else {
            following.zoomRange = Self.defaultFollowingMinZoom...Self.defaultFollowingMaxZoom
        }
        following.defaultPitch = Self.defaultFollowingPitch
        following.intersectionDensity.enabled = true
        following.intersectionDensity.averageDistanceMultiplier = Self.defaultIntersectionMultiplier
        following.geometryFramingAfterManeuver.enabled = true
        following.geometryFramingAfterManeuver.distanceToCoalesceCompoundManeuvers = Self.defaultCompoundManeuverDistance
        following.geometryFramingAfterManeuver.distanceToFrameAfterManeuver = Self.defaultPostManeuverFramingDistance
        following.pitchNearManeuver.enabled = true
        following.pitchNearManeuver.triggerDistanceToManeuver = Self.defaultPitchNearManeuverDistance
        mobileDataSource.options.followingCameraOptions = following
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
