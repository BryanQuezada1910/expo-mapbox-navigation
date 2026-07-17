import ExpoModulesCore
import MapboxNavigationCore
import MapboxMaps
import MapboxNavigationUIKit
import MapboxDirections
import Combine
import ObjectiveC

private let swizzleBundleOnce: Void = {
    let originalSelector = #selector(Bundle.localizedString(forKey:value:table:))
    let swizzledSelector = #selector(Bundle.customLocalizedString(forKey:value:table:))
    guard let originalMethod = class_getInstanceMethod(Bundle.self, originalSelector),
          let swizzledMethod = class_getInstanceMethod(Bundle.self, swizzledSelector) else { return }
    method_exchangeImplementations(originalMethod, swizzledMethod)
}()

extension Bundle {
    @objc func customLocalizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let language = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first else {
            return self.customLocalizedString(forKey: key, value: value, table: tableName)
        }
        // Intentar encontrar el bundle específico (ej: es-MX) o el base (ej: es)
        var path = self.path(forResource: language, ofType: "lproj") 
            ?? self.path(forResource: String(language.prefix(2)), ofType: "lproj")
            
        // Mapbox usa en-US en lugar de en
        if path == nil && language.hasPrefix("en") {
            path = self.path(forResource: "en-US", ofType: "lproj")
        }
        
        if let validPath = path, let languageBundle = Bundle(path: validPath) {
            return languageBundle.customLocalizedString(forKey: key, value: value, table: tableName)
        } else {
            return self.customLocalizedString(forKey: key, value: value, table: tableName)
        }
    }
}
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
        _ = swizzleBundleOnce
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
    var _forceRecreateNavigationController: Bool = false
    var bottomLegendLabel: UILabel? = nil
    var showCancelButton: Bool = true

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
                
                // Add Speed Limit Label Logic
                DispatchQueue.main.async {
                    if let speedLimitView = self.navigationViewController?.view.findViews(subclassOf: SpeedLimitView.self).first,
                       let parentView = self.navigationViewController?.view {
                        var unitLabel = parentView.viewWithTag(999) as? UILabel
                        if unitLabel == nil {
                            unitLabel = UILabel()
                            unitLabel!.tag = 999
                            unitLabel!.font = UIFont.systemFont(ofSize: 12, weight: .bold)
                            unitLabel!.backgroundColor = UIColor.white.withAlphaComponent(0.9)
                            unitLabel!.layer.cornerRadius = 4
                            unitLabel!.clipsToBounds = true
                            unitLabel!.textColor = .black
                            unitLabel!.textAlignment = .center
                            unitLabel!.translatesAutoresizingMaskIntoConstraints = false
                            
                            parentView.addSubview(unitLabel!)
                            
                            NSLayoutConstraint.activate([
                                unitLabel!.centerXAnchor.constraint(equalTo: speedLimitView.centerXAnchor),
                                unitLabel!.topAnchor.constraint(equalTo: speedLimitView.bottomAnchor, constant: 2),
                                unitLabel!.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),
                                unitLabel!.heightAnchor.constraint(equalToConstant: 16)
                            ])
                        }
                        
                        if speedLimitView.speedLimit != nil && !speedLimitView.isHidden && speedLimitView.alpha > 0 {
                            if let location = self.navigationViewController?.navigationMapView?.mapView.location.latestLocation?.coordinate {
                                let inUS = self.isUS(lat: location.latitude, lon: location.longitude)
                                unitLabel!.text = inUS ? "mph" : "km/h"
                            }
                            unitLabel!.isHidden = false
                        } else {
                            unitLabel!.isHidden = true
                        }
                    }
                }
                
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

    func isUS(lat: Double, lon: Double) -> Bool {
        if lat > 32.72 { return true }
        if lat < 25.83 { return false }
        let borderLat: Double
        if lon < -117.10 { borderLat = 32.53 }
        else if lon < -106.48 {
            borderLat = 32.53 + (31.76 - 32.53) * ((lon - -117.10) / (-106.48 - -117.10))
        }
        else if lon < -97.43 {
            borderLat = 31.76 + (25.89 - 31.76) * ((lon - -106.48) / (-97.43 - -106.48))
        }
        else { borderLat = 25.89 }
        return lat >= borderLat
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
        let previousLocale = currentLocale.identifier
        if(locale != nil){
            currentLocale = Locale(identifier: locale!)
        } else {
            currentLocale = Locale.current
        }
        if previousLocale != currentLocale.identifier {
            _forceRecreateNavigationController = true
        }
        UserDefaults.standard.set([currentLocale.identifier], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
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

    func setBottomLegend(legend: String?){
        DispatchQueue.main.async {
            self.bottomLegendLabel?.text = legend
            self.bottomLegendLabel?.isHidden = legend == nil || legend!.isEmpty
        }
    }

    func setShowCancelButton(show: Bool?){
        showCancelButton = show ?? true
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
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "max_height", value: String(format: "%.1f", vehicleMaxHeight ?? 0.0)),
            URLQueryItem(name: "max_width", value: String(format: "%.1f", vehicleMaxWidth ?? 0.0))
        ]
        if let excludes = currentRouteExcludeList, !excludes.isEmpty {
            queryItems.append(URLQueryItem(name: "exclude", value: excludes.joined(separator: ",")))
        }
            
        let routeOptions = NavigationRouteOptions(
            waypoints: waypoints, 
            profileIdentifier: currentRouteProfile != nil ? ProfileIdentifier(rawValue: currentRouteProfile!) : nil,
            queryItems: queryItems,
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

        var matchQueryItems: [URLQueryItem] = []
        if let excludes = currentRouteExcludeList, !excludes.isEmpty {
            matchQueryItems.append(URLQueryItem(name: "exclude", value: excludes.joined(separator: ",")))
        }

        let matchOptions = NavigationMatchOptions(
            waypoints: waypoints, 
            profileIdentifier: matchProfile,
            queryItems: matchQueryItems.isEmpty ? nil : matchQueryItems,
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
        bottomBanner.dateFormatter.dateFormat = "h:mm a"

        let navigationOptions = NavigationOptions(
            mapboxNavigation: self.mapboxNavigation!,
            voiceController: ExpoMapboxNavigationViewController.navigationProvider.routeVoiceController,
            eventsManager: ExpoMapboxNavigationViewController.navigationProvider.eventsManager(),
            styles: [DayStyle()],
            topBanner: topBanner,
            bottomBanner: bottomBanner
        )

        let newNavigationControllerRequired = navigationViewController == nil || _forceRecreateNavigationController

        if(newNavigationControllerRequired){
            if let oldVC = navigationViewController {
                oldVC.willMove(toParent: nil)
                oldVC.view.removeFromSuperview()
                oldVC.removeFromParent()
            }
            navigationViewController = NavigationViewController(
                navigationRoutes: navigationRoutes,
                navigationOptions: navigationOptions
            )
            _forceRecreateNavigationController = false
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
        
        if !showCancelButton {
            cancelButton.isHidden = true
        }

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
        
        // Add bottom legend label if it doesn't exist
        if bottomLegendLabel == nil {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.textColor = UIColor.darkGray
            label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
            label.textAlignment = .center
            label.backgroundColor = .clear
            
            bottomLegendLabel = label
            navigationViewController.view.addSubview(label)
            
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: navigationViewController.view.centerXAnchor),
                label.bottomAnchor.constraint(equalTo: navigationViewController.navigationView.bottomBannerContainerView.topAnchor, constant: -10),
                label.heightAnchor.constraint(equalToConstant: 24)
            ])
        }

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
