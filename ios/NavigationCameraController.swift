import Combine
import CoreLocation
import MapboxMaps
import MapboxNavigationCore
import MapboxNavigationUIKit
import UIKit

@MainActor
final class NavigationCameraController: NSObject {
    static let defaultFollowingMinZoom: Double = 16.2
    static let defaultFollowingMaxZoom: Double = 17.6
    static let defaultFollowingPitch: Double = 50.0
    static let defaultIntersectionMultiplier: Double = 2.5
    static let defaultCompoundManeuverDistance: Double = 50.0
    static let defaultPostManeuverFramingDistance: Double = 35.0
    static let defaultPitchNearManeuverDistance: Double = 70.0

    let policy = NavigationCameraPolicy()

    private weak var controller: NavigationViewController?
    private weak var nativeOverviewButton: UIButton?
    private weak var controlsView: NavigationCameraControlsView?
    private weak var fallbackMapView: MapView?
    private weak var observedMapView: MapView?
    private var stateSubscription: AnyCancellable?
    private var plannedViewport: PlannedRouteViewportDataSource?
    private var locale = Locale.current
    private var followingZoom: Double?
    private var fallbackCoordinates: [CLLocationCoordinate2D] = []
    private var fallbackInitialLocation: CLLocationCoordinate2D?
    private var fallbackLatestLocation: CLLocationCoordinate2D?
    private var fallbackFollowingZoom: Double = NavigationCameraController.defaultFollowingMinZoom

    var currentNavigationCameraState: NavigationCameraState {
        if let state = controller?.navigationMapView?.navigationCamera.currentCameraState {
            return state
        }
        return Self.cameraState(for: policy.mode)
    }

    func bindControlsView(_ view: NavigationCameraControlsView) {
        controlsView = view
        updateControls()
    }

    func setLocale(_ locale: Locale) {
        self.locale = locale
        updateControls()
    }

    func setFollowingZoom(_ zoom: Double?) {
        followingZoom = zoom
        if let zoom = zoom, zoom.isFinite, zoom > 0 {
            fallbackFollowingZoom = zoom
        }
        guard let map = controller?.navigationMapView else { return }
        let camera = map.navigationCamera
        if let viewport = camera.viewportDataSource as? PlannedRouteViewportDataSource {
            applyFollowingOptions(to: viewport.base)
        } else {
            applyFollowingOptions(to: camera.viewportDataSource)
        }
    }

    func attachFallback(
        mapView: MapView,
        coordinates: [CLLocationCoordinate2D],
        initialLocation: CLLocationCoordinate2D?,
        followingZoom: Double
    ) {
        fallbackMapView = mapView
        fallbackCoordinates = coordinates
        fallbackInitialLocation = initialLocation
        fallbackFollowingZoom = max(followingZoom, Self.defaultFollowingMinZoom)
        attachGestureObservers(to: mapView)
        if policy.shouldFollowLocationUpdates, let target = fallbackLatestLocation ?? initialLocation {
            applyFallbackFollowCamera(on: mapView, center: target, animated: false)
        }
        updateControls()
    }

    func setFallbackInitialLocation(_ location: CLLocationCoordinate2D, zoom: Double) {
        fallbackInitialLocation = location
        fallbackFollowingZoom = max(zoom, Self.defaultFollowingMinZoom)
        guard let mapView = fallbackMapView,
              fallbackLatestLocation == nil,
              policy.shouldFollowLocationUpdates else { return }
        applyFallbackFollowCamera(on: mapView, center: location, animated: false)
    }

    func updateFallbackLocation(_ coordinate: CLLocationCoordinate2D, zoom: Double) {
        fallbackLatestLocation = coordinate
        fallbackFollowingZoom = max(zoom, Self.defaultFollowingMinZoom)
        guard let mapView = fallbackMapView, policy.shouldFollowLocationUpdates else { return }
        applyFallbackFollowCamera(on: mapView, center: coordinate, animated: false)
    }

    func attach(
        to controller: NavigationViewController,
        planned: Bool,
        coordinates: [CLLocationCoordinate2D],
        preserving previousState: NavigationCameraState? = nil
    ) {
        fallbackMapView = nil
        fallbackCoordinates = coordinates
        policy.prepareForAttachment(preserving: previousState.map(Self.cameraMode(for:)))

        if self.controller !== controller {
            self.controller = controller
            let buttons = controller.floatingButtons ?? []
            let overview = buttons.first { button in
                button.allTargets.contains { target in
                    button.actions(forTarget: target, forControlEvent: .touchUpInside)?.contains {
                        $0.localizedCaseInsensitiveContains("overview")
                    } == true
                }
            } ?? buttons.first
            nativeOverviewButton = overview
            if let overview = overview {
                controller.floatingButtons = buttons.filter { $0 !== overview }
            }
            stateSubscription?.cancel()
            stateSubscription = controller.navigationMapView?.navigationCamera.cameraStates.sink { [weak self] state in
                guard let self = self else { return }
                if let overrideMode = self.policy.didObserveCameraState(Self.cameraMode(for: state)) {
                    controller.navigationMapView?.navigationCamera.update(cameraState: Self.cameraState(for: overrideMode))
                }
                self.updateControls()
            }
        }
        if let mapView = controller.navigationMapView?.mapView {
            attachGestureObservers(to: mapView)
        }
        configureViewport(planned: planned, coordinates: coordinates)
        if let navigationCamera = controller.navigationMapView?.navigationCamera {
            if policy.mode != .following {
                navigationCamera.update(cameraState: Self.cameraState(for: policy.mode))
            } else if let overrideMode = policy.didObserveCameraState(Self.cameraMode(for: navigationCamera.currentCameraState)) {
                navigationCamera.update(cameraState: Self.cameraState(for: overrideMode))
            }
        }
        updateControls()
    }

    func configureViewport(planned: Bool, coordinates: [CLLocationCoordinate2D]) {
        fallbackCoordinates = coordinates
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
                policy.willReassignViewportDataSource()
                let targetMode = policy.mode
                camera.viewportDataSource = viewport
                if targetMode != .following {
                    camera.update(cameraState: Self.cameraState(for: targetMode))
                }
            }
        } else if let viewport = camera.viewportDataSource as? PlannedRouteViewportDataSource {
            applyFollowingOptions(to: viewport.base)
            policy.willReassignViewportDataSource()
            let targetMode = policy.mode
            camera.viewportDataSource = viewport.base
            plannedViewport = nil
            if targetMode != .following {
                camera.update(cameraState: Self.cameraState(for: targetMode))
            }
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

    func setCoordinates(_ coordinates: [CLLocationCoordinate2D]) {
        fallbackCoordinates = coordinates
        plannedViewport?.setCoordinates(coordinates)
    }

    func requestOverview() {
        policy.requestOverview()
        if let navigationCamera = controller?.navigationMapView?.navigationCamera {
            navigationCamera.update(cameraState: .overview)
        } else if let mapView = fallbackMapView {
            applyFallbackOverviewCamera(on: mapView)
        }
        updateControls()
    }

    func requestFollowing(fallbackCoordinate: CLLocationCoordinate2D? = nil, zoom: Double? = nil) {
        if let coordinate = fallbackCoordinate {
            fallbackLatestLocation = coordinate
        }
        if let zoom = zoom, zoom.isFinite, zoom > 0 {
            fallbackFollowingZoom = max(zoom, Self.defaultFollowingMinZoom)
        }
        policy.requestFollowing()
        if let navigationCamera = controller?.navigationMapView?.navigationCamera {
            navigationCamera.update(cameraState: .following)
        } else if let mapView = fallbackMapView, let target = fallbackLatestLocation ?? fallbackInitialLocation {
            applyFallbackFollowCamera(on: mapView, center: target, animated: true)
        }
        updateControls()
    }

    func restore(_ state: NavigationCameraState?) {
        guard let state = state else { return }
        policy.prepareForAttachment(preserving: Self.cameraMode(for: state))
        controller?.navigationMapView?.navigationCamera.update(cameraState: state)
        updateControls()
    }

    func detach() {
        stateSubscription?.cancel()
        stateSubscription = nil
        detachGestureObservers()
        plannedViewport = nil
        nativeOverviewButton = nil
        controller = nil
        fallbackMapView = nil
        fallbackCoordinates = []
        fallbackInitialLocation = nil
        fallbackLatestLocation = nil
        policy.reset()
        updateControls()
    }

    func updateControls() {
        let strings = NavigationStrings(locale: locale)
        controlsView?.update(buttonState: policy.buttonState, strings: strings)
        hideNativeCameraButtons()
    }

    private func hideNativeCameraButtons() {
        if let overview = nativeOverviewButton {
            overview.isHidden = true
            overview.alpha = 0
            overview.isUserInteractionEnabled = false
        }
        guard let controller = controller else { return }
        for button in controller.navigationView.findViews(subclassOf: ResumeButton.self) {
            button.isHidden = true
            button.alpha = 0
            button.isUserInteractionEnabled = false
        }
    }

    private func attachGestureObservers(to mapView: MapView) {
        if observedMapView === mapView { return }
        detachGestureObservers()
        observedMapView = mapView
        guard let gestures = mapView.gestures else { return }
        let continuousRecognizers = [
            gestures.panGestureRecognizer,
            gestures.pinchGestureRecognizer,
            gestures.rotateGestureRecognizer,
            gestures.pitchGestureRecognizer,
            gestures.quickZoomGestureRecognizer
        ]
        for recognizer in continuousRecognizers {
            recognizer.addTarget(self, action: #selector(handleContinuousMapGesture(_:)))
        }
        let discreteRecognizers = [
            gestures.doubleTapToZoomInGestureRecognizer,
            gestures.doubleTouchToZoomOutGestureRecognizer
        ]
        for recognizer in discreteRecognizers {
            recognizer.addTarget(self, action: #selector(handleDiscreteMapGesture(_:)))
        }
    }

    private func detachGestureObservers() {
        guard let mapView = observedMapView, let gestures = mapView.gestures else {
            observedMapView = nil
            return
        }
        let continuousRecognizers = [
            gestures.panGestureRecognizer,
            gestures.pinchGestureRecognizer,
            gestures.rotateGestureRecognizer,
            gestures.pitchGestureRecognizer,
            gestures.quickZoomGestureRecognizer
        ]
        for recognizer in continuousRecognizers {
            recognizer.removeTarget(self, action: #selector(handleContinuousMapGesture(_:)))
        }
        let discreteRecognizers = [
            gestures.doubleTapToZoomInGestureRecognizer,
            gestures.doubleTouchToZoomOutGestureRecognizer
        ]
        for recognizer in discreteRecognizers {
            recognizer.removeTarget(self, action: #selector(handleDiscreteMapGesture(_:)))
        }
        observedMapView = nil
    }

    @objc private func handleContinuousMapGesture(_ recognizer: UIGestureRecognizer) {
        guard recognizer.state == .began || recognizer.state == .changed else { return }
        handleUserMapInteraction()
    }

    @objc private func handleDiscreteMapGesture(_ recognizer: UIGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        handleUserMapInteraction()
    }

    private func handleUserMapInteraction() {
        guard policy.mode != .idle else { return }
        policy.userDidInteractWithMap()
        if let navigationCamera = controller?.navigationMapView?.navigationCamera,
           navigationCamera.currentCameraState != .idle {
            navigationCamera.update(cameraState: .idle)
        }
        updateControls()
    }

    private func applyFallbackFollowCamera(on mapView: MapView, center: CLLocationCoordinate2D, animated: Bool) {
        let options = CameraOptions(
            center: center,
            zoom: fallbackFollowingZoom,
            pitch: CGFloat(Self.defaultFollowingPitch)
        )
        if animated {
            mapView.camera.ease(to: options, duration: 0.35)
        } else {
            mapView.mapboxMap.setCamera(to: options)
        }
    }

    private func applyFallbackOverviewCamera(on mapView: MapView) {
        if fallbackCoordinates.count >= 2 {
            let topInset = max(mapView.safeAreaInsets.top + 80, 96)
            let bottomInset = max(mapView.safeAreaInsets.bottom + 48, 80)
            let padding = UIEdgeInsets(top: topInset, left: 48, bottom: bottomInset, right: 80)
            if let camera = try? mapView.mapboxMap.camera(
                for: fallbackCoordinates,
                camera: CameraOptions(padding: padding, bearing: 0, pitch: 0),
                coordinatesPadding: nil,
                maxZoom: nil,
                offset: nil
            ) {
                mapView.camera.ease(to: camera, duration: 0.45)
                return
            }
        }
        if let point = fallbackCoordinates.first ?? fallbackLatestLocation ?? fallbackInitialLocation {
            let options = CameraOptions(center: point, zoom: fallbackFollowingZoom, bearing: 0, pitch: 0)
            mapView.camera.ease(to: options, duration: 0.45)
        }
    }

    private static func cameraMode(for state: NavigationCameraState) -> NavigationCameraMode {
        switch state {
        case .idle:
            return .idle
        case .following:
            return .following
        case .overview:
            return .overview
        @unknown default:
            return .idle
        }
    }

    private static func cameraState(for mode: NavigationCameraMode) -> NavigationCameraState {
        switch mode {
        case .idle:
            return .idle
        case .following:
            return .following
        case .overview:
            return .overview
        }
    }
}
