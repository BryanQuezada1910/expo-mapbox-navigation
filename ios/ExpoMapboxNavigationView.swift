import ExpoModulesCore
import MapboxNavigationCore
import MapboxMaps
import MapboxNavigationUIKit
import MapboxDirections
import Combine


class ExpoMapboxNavigationView: ExpoView {
    private let onRouteProgressChanged = EventDispatcher()
    private let onCancelNavigation = EventDispatcher()
    private let onWaypointArrival = EventDispatcher()
    private let onFinalDestinationArrival = EventDispatcher()
    private let onRouteChanged = EventDispatcher()
    private let onUserOffRoute = EventDispatcher()
    private let onRoutesLoaded = EventDispatcher()
    private let onRouteFailedToLoad = EventDispatcher()
    private let onMarkerPress = EventDispatcher()

    let controller = ExpoMapboxNavigationViewController()

    required init(appContext: AppContext? = nil) {
        super.init(appContext: appContext)
        clipsToBounds = true
        addSubview(controller.view)

        // Use a closure that captures self weakly to dispatch events.
        // When this ExpoView is deallocated, the weak reference becomes nil
        // and the EventDispatcher's internal handler (which also holds
        // a [weak self] to the ExpoFabricView) won't be called at all,
        // preventing the "Cannot dispatch an event while the managing
        // ExpoFabricView is deallocated" warning.
        controller.onEvent = { [weak self] eventName, payload in
            guard let self = self else { return }
            switch eventName {
            case "onRouteProgressChanged":
                self.onRouteProgressChanged(payload)
            case "onCancelNavigation":
                self.onCancelNavigation(payload)
            case "onWaypointArrival":
                self.onWaypointArrival(payload)
            case "onFinalDestinationArrival":
                self.onFinalDestinationArrival(payload)
            case "onRouteChanged":
                self.onRouteChanged(payload)
            case "onUserOffRoute":
                self.onUserOffRoute(payload)
            case "onRoutesLoaded":
                self.onRoutesLoaded(payload)
            case "onRouteFailedToLoad":
                self.onRouteFailedToLoad(payload)
            case "onMarkerPress":
                self.onMarkerPress(payload)
            default:
                break
            }
        }
    }

    override func layoutSubviews() {
        controller.view.frame = bounds
    }
}


class ExpoMapboxNavigationViewController: UIViewController {
    static let navigationProvider: MapboxNavigationProvider = MapboxNavigationProvider(coreConfig: CoreConfig(routingConfig: RoutingConfig(fasterRouteDetectionConfig: Optional<FasterRouteDetectionConfig>.none),locationSource: .live ))
    var mapboxNavigation: MapboxNavigation? = nil
    var routingProvider: RoutingProvider? = nil
    var navigation: NavigationController? = nil
    var tripSession: SessionController? = nil
    var navigationViewController: NavigationViewController? = nil
    
    var currentCoordinates: Array<CLLocationCoordinate2D>? = nil
    var initialLocation: CLLocationCoordinate2D? = nil
    var initialLocationZoom: Double? = nil
    var currentWaypointIndices: Array<Int>? = nil
    var currentLocale: Locale = Locale.current
    var currentRouteProfile: String? = nil
    var currentRouteExcludeList: Array<String>? = nil
    var currentMapStyle: String? = nil
    var currentCustomRasterSourceUrl: String? = nil
    var currentPlaceCustomRasterLayerAbove: String? = nil
    var currentDisableAlternativeRoutes: Bool? = nil
    var currentFollowingZoom: Double? = nil
    var isUsingRouteMatchingApi: Bool = false
    var vehicleMaxHeight: Double? = nil
    var vehicleMaxWidth: Double? = nil
    var currentMarkers: Array<Dictionary<String, Any>>? = nil
    var pointAnnotationManager: PointAnnotationManager? = nil

    /// Callback for dispatching events back to the ExpoView.
    /// This closure captures the ExpoView weakly, so when the view is
    /// deallocated, calling this becomes a safe no-op and the
    /// EventDispatcher's internal handler (which holds a weak ref to the
    /// ExpoFabricView) is never invoked.
    var onEvent: ((String, [String: Any]) -> Void)?

    var calculateRoutesTask: Task<Void, Error>? = nil
    private var updateDebounceTimer: Timer? = nil
    private var routeProgressCancellable: AnyCancellable? = nil
    private var waypointArrivalCancellable: AnyCancellable? = nil
    private var reroutingCancellable: AnyCancellable? = nil
    private var sessionCancellable: AnyCancellable? = nil

    init() {
        super.init(nibName: nil, bundle: nil)
        mapboxNavigation = ExpoMapboxNavigationViewController.navigationProvider.mapboxNavigation
        routingProvider = mapboxNavigation!.routingProvider()
        navigation = mapboxNavigation!.navigation()
        tripSession = mapboxNavigation!.tripSession()

        routeProgressCancellable = navigation!.routeProgress.sink { progressState in
            if(progressState != nil){


                // For some reason the maneuver arrows sometimes (not consistently) show up the same color as the route line making them invisible.
                // This is a hack to always ensure the arrows are visible.
                try? self.navigationViewController?.navigationMapView?.mapView.mapboxMap.setLayerProperty(
                    for: "com.mapbox.navigation.arrow.next",
                    property: "line-color",
                    value: "#FFFFFF" 
                )
                try? self.navigationViewController?.navigationMapView?.mapView.mapboxMap.setLayerProperty(
                    for: "com.mapbox.navigation.arrow.next.stroke",
                    property: "line-color",
                    value: "#FFFFFF" 
                )
                try? self.navigationViewController?.navigationMapView?.mapView.mapboxMap.setLayerProperty(
                    for: "com.mapbox.navigation.arrow.next.symbol",
                    property: "icon-color",
                    value: "#FFFFFF" 
                )
                try? self.navigationViewController?.navigationMapView?.mapView.mapboxMap.setLayerProperty(
                    for: "com.mapbox.navigation.arrow.next.symbol.casing",
                    property: "icon-color",
                    value: "#FFFFFF" 
                )
                
               self.onEvent?("onRouteProgressChanged", [
                    "distanceRemaining": progressState!.routeProgress.distanceRemaining,
                    "distanceTraveled": progressState!.routeProgress.distanceTraveled,
                    "durationRemaining": progressState!.routeProgress.durationRemaining,
                    "fractionTraveled": progressState!.routeProgress.fractionTraveled,
                ])
            }
        }

        waypointArrivalCancellable = navigation!.waypointsArrival.sink { arrivalStatus in
            let event = arrivalStatus.event
            if event is WaypointArrivalStatus.Events.ToFinalDestination {
                self.onEvent?("onFinalDestinationArrival", [:])
            } else if event is WaypointArrivalStatus.Events.ToWaypoint {
                self.onEvent?("onWaypointArrival", [:])
            }
        }

        reroutingCancellable = navigation!.rerouting.sink { rerouteStatus in
            self.onEvent?("onRouteChanged", [:])
        }

        sessionCancellable = tripSession!.session.sink { session in 
            let state = session.state
            switch state {
                case .activeGuidance(let activeGuidanceState):
                    switch(activeGuidanceState){
                        case .offRoute:
                            self.onEvent?("onUserOffRoute", [:])
                        default: break
                    }
                default: break
            }
        }

    }

    deinit {
        calculateRoutesTask?.cancel()
        updateDebounceTimer?.invalidate()
        routeProgressCancellable?.cancel()
        waypointArrivalCancellable?.cancel()
        reroutingCancellable?.cancel()
        sessionCancellable?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { @MainActor in self.tripSession?.startFreeDrive() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        Task { @MainActor in tripSession?.setToIdle() } // Stops navigation
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        fatalError("This controller should not be loaded through a story board")
    }

    func addCustomRasterLayer() {
        let navigationMapView = navigationViewController?.navigationMapView
        let sourceId = "raster-source"
        let layerId = "raster-layer"

        if(currentCustomRasterSourceUrl == nil){
            if let mapView = navigationMapView?.mapView.mapboxMap {
                if mapView.layerExists(withId: layerId) {
                    try? mapView.removeLayer(withId: layerId)
                }
                if mapView.sourceExists(withId: sourceId) {
                    try? mapView.removeSource(withId: sourceId)
                }
            }
            return
        }

        let sourceUrl = currentCustomRasterSourceUrl! 

        var rasterSource = RasterSource(id: sourceId)

        rasterSource.tiles = [sourceUrl]
        rasterSource.tileSize = 256

        let rasterLayer = RasterLayer(id: layerId, source: sourceId)


        if let mapView = navigationMapView?.mapView.mapboxMap {
            if mapView.layerExists(withId: layerId) {
                try? mapView.removeLayer(withId: layerId)
            }
            if mapView.sourceExists(withId: sourceId) {
                try? mapView.removeSource(withId: sourceId)
            }

            try? mapView.addSource(rasterSource)
            try? mapView.addLayer(rasterLayer, layerPosition: .above(currentPlaceCustomRasterLayerAbove ?? "water"))    
        }
    }


    func setCoordinates(coordinates: Array<CLLocationCoordinate2D>) {
        currentCoordinates = coordinates
        update()
    }

    func setVehicleMaxHeight(maxHeight: Double?) {
        vehicleMaxHeight = maxHeight
        update()
    }

    func setVehicleMaxWidth(maxWidth: Double?) {
        vehicleMaxWidth = maxWidth
        update()
    }

    func setLocale(locale: String?) {
        if(locale != nil){
            currentLocale = Locale(identifier: locale!)
        } else {
            currentLocale = Locale.current
        }
        update()
    }

    func setIsUsingRouteMatchingApi(useRouteMatchingApi: Bool?){
        isUsingRouteMatchingApi = useRouteMatchingApi ?? false
        update()
    }

    func setWaypointIndices(waypointIndices: Array<Int>?){
        currentWaypointIndices = waypointIndices
        update()
    }

    func setRouteProfile(profile: String?){
        currentRouteProfile = profile
        update()
    }

    func setRouteExcludeList(excludeList: Array<String>?){
        currentRouteExcludeList = excludeList
        update()
    }

    func setMapStyle(style: String?){
        currentMapStyle = style
        update()
    }

    func setCustomRasterSourceUrl(url: String?){
        currentCustomRasterSourceUrl = url
        update()
    }

    func setPlaceCustomRasterLayerAbove(layerId: String?){
        currentPlaceCustomRasterLayerAbove = layerId
        update()
    }

    func setDisableAlternativeRoutes(disableAlternativeRoutes: Bool?){
        currentDisableAlternativeRoutes = disableAlternativeRoutes
        update()
    }

    func recenterMap(){
        let navigationMapView = navigationViewController?.navigationMapView
        navigationMapView?.navigationCamera.update(cameraState: .following)
    }

    func setIsMuted(isMuted: Bool?){
        if(isMuted != nil){
            ExpoMapboxNavigationViewController.navigationProvider.routeVoiceController.speechSynthesizer.muted = isMuted!
        }
    }

    func setInitialLocation(location: CLLocationCoordinate2D, zoom: Double?){
        initialLocation = location
        initialLocationZoom = zoom
        let navigationMapView = navigationViewController?.navigationMapView
        if(initialLocation != nil && navigationMapView != nil){
            navigationMapView!.mapView.mapboxMap.setCamera(to: CameraOptions(center: initialLocation!, zoom: initialLocationZoom ?? 15))
        }
    }

    func setFollowingZoom(followingZoom: Double?){
        let navigationMapView = navigationViewController?.navigationMapView
        currentFollowingZoom = followingZoom
        if(navigationMapView != nil && followingZoom != nil){
            let newDataSource = MobileViewportDataSource(navigationMapView!.mapView)
            newDataSource.options.followingCameraOptions.zoomRange = followingZoom!...followingZoom!
            navigationMapView?.navigationCamera.viewportDataSource = newDataSource
        }
    }

    func setMarkers(markers: Array<Dictionary<String, Any>>?) {
        currentMarkers = markers
        updateMarkers()
    }

    func updateMarkers() {
        guard let navigationMapView = navigationViewController?.navigationMapView else { return }
        
        // Create annotation manager if it doesn't exist
        if pointAnnotationManager == nil {
            pointAnnotationManager = navigationMapView.mapView.annotations.makePointAnnotationManager()
            // Set delegate for tap handling
            pointAnnotationManager?.delegate = self
        }
        
        // Clear existing annotations
        pointAnnotationManager?.annotations = []
        
        guard let markers = currentMarkers else { return }
        
        var annotations: [PointAnnotation] = []
        
        for (index, marker) in markers.enumerated() {
            guard let lat = marker["latitude"] as? Double,
                  let lon = marker["longitude"] as? Double else {
                continue
            }
            
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            var annotation = PointAnnotation(id: marker["id"] as? String ?? "marker-\(index)", coordinate: coordinate)
            
            // Store marker data in userInfo using JSON encoding
            if let jsonData = try? JSONSerialization.data(withJSONObject: marker),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                annotation.userInfo = ["markerData": jsonString]
            }
            
            // Get marker color (default to red)
            let markerColor = parseColor(from: marker["color"] as? String) ?? .red
            
            // Set marker icon (círculo con letra: "P" Parada / "S" Stop según idioma)
            if let iconName = marker["iconName"] as? String, let image = UIImage(named: iconName) {
                annotation.image = .init(image: image, name: iconName)
            } else {
                let letter = (marker["markerLetter"] as? String).map { String($0.prefix(1)) } ?? "P"
                let stopImage = makeStopMarkerImage(color: markerColor, letter: letter, size: 56)
                if let img = stopImage {
                    let colorHex = markerColor.toHexString()
                    annotation.image = .init(image: img, name: "stop-\(letter)-\(colorHex)")
                }
            }
            
            annotation.iconSize = 1.0
            annotations.append(annotation)
        }
        
        pointAnnotationManager?.annotations = annotations
    }
    
    /// Genera imagen de marcador: círculo con borde blanco, relleno del color y letra centrada.
    /// La letra es "P" (Parada) en español o "S" (Stop) en inglés según markerLetter.
    func makeStopMarkerImage(color: UIColor, letter: String, size: CGFloat) -> UIImage? {
        let strokeWidth: CGFloat = 3
        let letterChar = String((letter.isEmpty ? "P" : String(letter.prefix(1))))
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let rect = CGRect(x: strokeWidth / 2, y: strokeWidth / 2, width: size - strokeWidth, height: size - strokeWidth)
            ctx.cgContext.setFillColor(color.cgColor)
            ctx.cgContext.fillEllipse(in: rect)
            ctx.cgContext.setStrokeColor(UIColor.white.cgColor)
            ctx.cgContext.setLineWidth(strokeWidth)
            ctx.cgContext.strokeEllipse(in: rect)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: size * 0.4),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]
            let textSize = letterChar.size(withAttributes: attrs)
            let textRect = CGRect(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2 - 1, width: textSize.width, height: textSize.height)
            letterChar.draw(in: textRect, withAttributes: attrs)
        }
        return image
    }
    
    // Helper function to parse color from string (hex or rgb format)
    func parseColor(from colorString: String?) -> UIColor? {
        guard let colorString = colorString else { return nil }
        
        // Handle hex format: #RRGGBB or #RGB
        if colorString.hasPrefix("#") {
            var hexString = colorString.dropFirst()
            if hexString.count == 3 {
                hexString = hexString.map { "\($0)\($0)" }.joined()[...]
            }
            if hexString.count == 6 {
                var rgbValue: UInt64 = 0
                Scanner(string: String(hexString)).scanHexInt64(&rgbValue)
                return UIColor(
                    red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                    green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                    blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
                    alpha: 1.0
                )
            }
        }
        
        // Handle rgb format: rgb(R, G, B)
        if colorString.lowercased().hasPrefix("rgb(") {
            let values = colorString
                .replacingOccurrences(of: "rgb(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            
            if values.count == 3 {
                return UIColor(
                    red: CGFloat(values[0]) / 255.0,
                    green: CGFloat(values[1]) / 255.0,
                    blue: CGFloat(values[2]) / 255.0,
                    alpha: 1.0
                )
            }
        }
        
        return nil
    }
    
    func update(){
        // Debounce: React Native sends props one-by-one in rapid succession.
        // Wait 80 ms so all props settle before firing a single Mapbox API call.
        updateDebounceTimer?.invalidate()
        updateDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.performUpdate()
        }
    }

    func performUpdate(){
        calculateRoutesTask?.cancel()

        if(currentCoordinates != nil){
            let waypoints = currentCoordinates!.enumerated().map {
                let index = $0
                let coordinate = $1
                var waypoint = Waypoint(coordinate: coordinate) 
                waypoint.separatesLegs = currentWaypointIndices == nil ? true : currentWaypointIndices!.contains(index)
                return waypoint
            }

            if(isUsingRouteMatchingApi){
                calculateMapMatchingRoutes(waypoints: waypoints)
            } else {
                calculateRoutes(waypoints: waypoints)
            }
        }
    }

    func calculateRoutes(waypoints: Array<Waypoint>){
        let routeOptions = NavigationRouteOptions(
            waypoints: waypoints, 
            profileIdentifier: currentRouteProfile != nil ? ProfileIdentifier(rawValue: currentRouteProfile!) : nil,
            queryItems: [
                URLQueryItem(name: "exclude", value: currentRouteExcludeList?.joined(separator: ",")),
                URLQueryItem(name: "max_height", value: String(format: "%.1f", vehicleMaxHeight ?? 0.0)),
                URLQueryItem(name: "max_width", value: String(format: "%.1f", vehicleMaxWidth ?? 0.0))
            ],
            locale: currentLocale, 
            distanceUnit: currentLocale.usesMetricSystem ? LengthFormatter.Unit.meter : LengthFormatter.Unit.mile
        )

        calculateRoutesTask = Task {
            switch await self.routingProvider!.calculateRoutes(options: routeOptions).result {
            case .failure(let error):
                self.onEvent?("onRouteFailedToLoad", [
                    "errorMessage": error.localizedDescription
                ])
                print(error.localizedDescription)
            case .success(let navigationRoutes):
                self.onRoutesCalculated(navigationRoutes: navigationRoutes)
            }
        }
    }

    func calculateMapMatchingRoutes(waypoints: Array<Waypoint>){
        var matchProfile: ProfileIdentifier? = nil
        if let currentProfile = currentRouteProfile {
            if currentProfile == "driving-traffic" {
                matchProfile = .automobile
            } else {
                matchProfile = ProfileIdentifier(rawValue: currentProfile)
            }
        }

        let matchOptions = NavigationMatchOptions(
            waypoints: waypoints, 
            profileIdentifier: matchProfile,
            queryItems: [URLQueryItem(name: "exclude", value: currentRouteExcludeList?.joined(separator: ","))],
            distanceUnit: currentLocale.usesMetricSystem ? LengthFormatter.Unit.meter : LengthFormatter.Unit.mile
        )
        matchOptions.locale = currentLocale


        calculateRoutesTask = Task {
            switch await self.routingProvider!.calculateRoutes(options: matchOptions).result {
            case .failure(let error):
                print("Map matching failed: \(error.localizedDescription). Falling back to regular routing...")
                self.calculateRoutes(waypoints: waypoints)
            case .success(let navigationRoutes):
                self.onRoutesCalculated(navigationRoutes: navigationRoutes)
            }
        }
    }

    @objc func cancelButtonClicked(_ sender: AnyObject?) {
        onEvent?("onCancelNavigation", [:])
    }

    func convertRoute(route: Route) -> Any {
        return [
            "distance": route.distance,
            "expectedTravelTime": route.expectedTravelTime,
            "legs": route.legs.map { leg in
                return [
                    "source": leg.source != nil ? [
                        "latitude": leg.source!.coordinate.latitude,
                        "longitude": leg.source!.coordinate.longitude
                    ] : nil,
                    "destination": leg.destination != nil ? [
                        "latitude": leg.destination!.coordinate.latitude,
                        "longitude": leg.destination!.coordinate.longitude
                    ] : nil,
                    "steps": leg.steps.map { step in
                        return [
                            "shape": step.shape != nil ? [
                                "coordinates": step.shape!.coordinates.map { coordinate in
                                    return [
                                        "latitude": coordinate.latitude,
                                        "longitude": coordinate.longitude,
                                    ]
                                }
                            ] : nil
                        ]
                    }
                ]
            }
        ]
    }

    func onRoutesCalculated(navigationRoutes: NavigationRoutes){
        onEvent?("onRoutesLoaded", [
            "routes": [
                "mainRoute": convertRoute(route: navigationRoutes.mainRoute.route),
                "alternativeRoutes": navigationRoutes.alternativeRoutes.map { convertRoute(route: $0.route) }
            ]
        ])

        let topBanner = TopBannerViewController()
        topBanner.instructionsBannerView.distanceFormatter.locale = currentLocale
        let bottomBanner = BottomBannerViewController()
        bottomBanner.distanceFormatter.locale = currentLocale
        bottomBanner.dateFormatter.locale = currentLocale

        let navigationOptions = NavigationOptions(
            mapboxNavigation: self.mapboxNavigation!,
            voiceController: ExpoMapboxNavigationViewController.navigationProvider.routeVoiceController,
            eventsManager: ExpoMapboxNavigationViewController.navigationProvider.eventsManager(),
            styles: [DayStyle()],
            topBanner: topBanner,
            bottomBanner: bottomBanner
        )

        let newNavigationControllerRequired = navigationViewController == nil

        if(newNavigationControllerRequired){
            navigationViewController = NavigationViewController(
                navigationRoutes: navigationRoutes,
                navigationOptions: navigationOptions
            )
        } else {
            navigationViewController!.prepareViewLoading(
                navigationRoutes: navigationRoutes,
                navigationOptions: navigationOptions
            )
        }
        
        let navigationViewController = navigationViewController!

        navigationViewController.showsContinuousAlternatives = currentDisableAlternativeRoutes != true
        navigationViewController.usesNightStyleWhileInTunnel = false
        navigationViewController.automaticallyAdjustsStyleForTimeOfDay = false

        let navigationMapView = navigationViewController.navigationMapView
        navigationMapView!.puckType = .puck2D(.navigationDefault)

        if(initialLocation != nil && newNavigationControllerRequired){
            navigationMapView!.mapView.mapboxMap.setCamera(to: CameraOptions(center: initialLocation!, zoom: initialLocationZoom ?? 15))
        }

        let style = currentMapStyle != nil ? StyleURI(rawValue: currentMapStyle!) : StyleURI.streets
        navigationMapView!.mapView.mapboxMap.loadStyle(style!, completion: { _ in
            navigationMapView!.localizeLabels(locale: self.currentLocale)
            do{
                try navigationMapView!.mapView.mapboxMap.localizeLabels(into: self.currentLocale)
            } catch {}
            self.addCustomRasterLayer()
            self.updateMarkers()
        })
        

        let cancelButton = navigationViewController.navigationView.bottomBannerContainerView.findViews(subclassOf: CancelButton.self)[0]
        cancelButton.addTarget(self, action: #selector(cancelButtonClicked), for: .touchUpInside)

        navigationViewController.delegate = self
        addChild(navigationViewController)
        view.addSubview(navigationViewController.view)
        navigationViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            navigationViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            navigationViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
            navigationViewController.view.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
            navigationViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0),
        ])
        didMove(toParent: self)
        mapboxNavigation!.tripSession().startActiveGuidance(with: navigationRoutes, startLegIndex: 0)
    }
}
extension ExpoMapboxNavigationViewController: NavigationViewControllerDelegate {
    func navigationViewController(_ navigationViewController: NavigationViewController, didRerouteAlong route: Route) {
        onEvent?("onRoutesLoaded", [
            "routes": [
                "mainRoute": convertRoute(route: route),
                "alternativeRoutes": []
            ]
        ])
    }

    func navigationViewControllerDidDismiss(
        _ navigationViewController: NavigationViewController,
        byCanceling canceled: Bool
    ) { }
}

extension ExpoMapboxNavigationViewController: AnnotationInteractionDelegate {
    func annotationManager(_ manager: AnnotationManager, didDetectTappedAnnotations annotations: [Annotation]) {
        guard let pointAnnotation = annotations.first as? PointAnnotation else { return }
        
        // Extract marker data from userInfo
        if let markerDataString = pointAnnotation.userInfo?["markerData"] as? String,
           let markerData = markerDataString.data(using: .utf8),
           let markerDict = try? JSONSerialization.jsonObject(with: markerData) as? [String: Any] {
            onEvent?("onMarkerPress", markerDict)
        }
    }
}

extension UIColor {
    func toHexString() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

extension UIView {
    func findViews<T: UIView>(subclassOf: T.Type) -> [T] {
        return recursiveSubviews.compactMap { $0 as? T }
    }

    var recursiveSubviews: [UIView] {
        return subviews + subviews.flatMap { $0.recursiveSubviews }
    }
}
