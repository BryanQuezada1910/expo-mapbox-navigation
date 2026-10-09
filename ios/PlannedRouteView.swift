import MapboxMaps
import MapboxNavigationCore
import CoreLocation
import UIKit

extension ExpoMapboxNavigationViewController {
    func setRouteMode(_ value: String?) { plannedMode = value == "planned"; update() }
    func setReroutingEnabled(_ value: Bool?) { reroutingEnabled = value ?? true; update() }
    func setRouteDeviationTolerance(_ value: Double?) {
        let next = value.flatMap { $0.isFinite && $0 > 0 && $0 <= 50 ? $0 : nil } ?? 25
        if next != routeDeviationTolerance { plannedController.reset() }
        routeDeviationTolerance = next
        update()
    }
    func setRouteRevision(_ value: String?) { routeRevision = value ?? ""; update() }
    func setPrefetchCoordinates(_ value: [CLLocationCoordinate2D]) { prefetchCoordinates = value; update() }
    func setFinalRouteChunk(_ value: Bool?) { finalRouteChunk = value ?? true }
    func setGuidanceEnabled(_ value: Bool?) {
        guidanceEnabled = value ?? false
        refreshPlannedInstructions()
    }
    func refreshPlannedInstructions() {
        guard plannedMode else { return }
        let progress = navigation?.currentRouteProgress?.routeProgress
        let arriving = progress?.currentLegProgress.currentStep.maneuverType == .arrive || progress?.currentLegProgress.upcomingStep?.maneuverType == .arrive
        let suppressed = !guidanceEnabled || (!finalRouteChunk && arriving)
        let synthesizer = ExpoMapboxNavigationViewController.navigationProvider.routeVoiceController.speechSynthesizer
        if !guidanceWasSuppressed { requestedMute = synthesizer.muted }
        if suppressed { synthesizer.stopSpeaking() }
        synthesizer.muted = requestedMute || suppressed
        guidanceWasSuppressed = suppressed
        navigationViewController?.navigationView.topBannerContainerView.isHidden = suppressed
    }
    func setPlannedRouteCoordinates(_ coordinates: [CLLocationCoordinate2D]) {
        let unchanged = plannedCoordinates.count == coordinates.count && zip(plannedCoordinates, coordinates).allSatisfy { pair in pair.0.latitude == pair.1.latitude && pair.0.longitude == pair.1.longitude }
        if !unchanged { plannedController.reset() }
        plannedCoordinates = coordinates
        drawPlannedRoute()
    }
    func setPlannedRouteProgress(_ progress: [String: Double]?) {
        guard plannedMode, let progress = progress else { return }
        if plannedProgressLabel == nil {
            let label = UILabel()
            label.textAlignment = .center
            label.textColor = .darkGray
            label.backgroundColor = UIColor.white.withAlphaComponent(0.95)
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                label.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
                label.heightAnchor.constraint(equalToConstant: 48)
            ])
            plannedProgressLabel = label
        }
        let distance = (progress["distanceRemaining"] ?? 0) / 1000
        let seconds = progress["durationRemaining"] ?? 0
        plannedProgressLabel?.text = seconds > 0 ? String(format: "%.1f km · %.0f min", distance, seconds / 60) : String(format: "%.1f km", distance)
        view.bringSubviewToFront(plannedProgressLabel!)
    }
    func drawPlannedRoute() {
        guard plannedMode else { return }
        if let map = navigationViewController?.navigationMapView?.mapView ?? plannedFallbackMap {
            plannedRenderer.draw(on: map, coordinates: plannedCoordinates)
        }
    }

    func preparePlannedMap() {
        guard plannedMode, navigationViewController == nil, plannedFallbackMap == nil else { return }
        let map = MapView(frame: view.bounds)
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        map.location.options.puckType = .puck2D(.navigationDefault)
        view.insertSubview(map, at: 0)
        plannedFallbackMap = map
        plannedStyleSubscription = map.mapboxMap.onStyleLoaded.observe { [weak self] _ in self?.drawPlannedRoute() }
        if let location = initialLocation { map.mapboxMap.setCamera(to: CameraOptions(center: location, zoom: initialLocationZoom ?? 15)) }
        tripSession?.startFreeDrive()
        drawPlannedRoute()
    }
    func applyRoutingPolicy() {
        var config = ExpoMapboxNavigationViewController.navigationProvider.coreConfig
        config.routingConfig.rerouteConfig.detectsReroute = reroutingEnabled && !plannedMode
        config.routingConfig.fasterRouteDetectionConfig = nil
        config.routingConfig.alternativeRoutesDetectionConfig = (plannedMode || currentDisableAlternativeRoutes == true) ? nil : .init()
        config.routingConfig.routeRefreshPeriod = plannedMode ? nil : 120
        ExpoMapboxNavigationViewController.navigationProvider.apply(coreConfig: config)
    }
}
