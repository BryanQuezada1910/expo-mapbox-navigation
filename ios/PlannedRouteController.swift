import MapboxNavigationCore
import MapboxDirections
import CoreLocation

@MainActor
final class PlannedRouteController {
    private let provider: () -> RoutingProvider?
    private let ready: (NavigationRoutes, String) -> Void
    private let failed: (String, String) -> Void
    private var cache: [String: NavigationRoutes] = [:]
    private var tasks: [String: Task<Void, Never>] = [:]
    private var generation = 0
    private var activeKey = ""
    private var activeRevision = ""
    init(provider: @escaping () -> RoutingProvider?, ready: @escaping (NavigationRoutes, String) -> Void, failed: @escaping (String, String) -> Void) {
        self.provider = provider; self.ready = ready; self.failed = failed
    }
    func reset() {
        generation += 1
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll(); cache.removeAll()
    }
    private func key(_ coordinates: [CLLocationCoordinate2D]) -> String {
        coordinates.map { "\($0.latitude),\($0.longitude)" }.joined(separator: ";")
    }
    func activate(_ coordinates: [CLLocationCoordinate2D], next: [CLLocationCoordinate2D], revision: String, tolerance: Double, locale: Locale) {
        activeKey = key(coordinates); activeRevision = revision
        request(coordinates, tolerance: tolerance, locale: locale)
        if next.count >= 2 { request(next, tolerance: tolerance, locale: locale) }
    }
    private func request(_ coordinates: [CLLocationCoordinate2D], tolerance: Double, locale: Locale) {
        let requestKey = key(coordinates)
        if let cached = cache[requestKey] {
            if requestKey == activeKey { ready(cached, activeRevision) }
            return
        }
        guard tasks[requestKey] == nil else { return }
        guard coordinates.count >= 2, coordinates.count <= 100, let provider = provider() else {
            if requestKey == activeKey { failed("Bloque de navegación inválido o servicio no disponible", activeRevision) }
            return
        }
        let waypoints = coordinates.enumerated().map { index, coordinate -> Waypoint in
            var waypoint = Waypoint(coordinate: coordinate)
            waypoint.separatesLegs = index == 0 || index == coordinates.count - 1
            return waypoint
        }
        let options = NavigationMatchOptions(waypoints: waypoints, profileIdentifier: .automobile,
            queryItems: [URLQueryItem(name: "radiuses", value: coordinates.map { _ in String(min(50, tolerance)) }.joined(separator: ";"))])
        options.locale = locale
        let requestGeneration = generation
        tasks[requestKey] = Task { [weak self] in
            let result = await provider.calculateRoutes(options: options).result
            guard let self = self, !Task.isCancelled, self.generation == requestGeneration else { return }
            self.tasks.removeValue(forKey: requestKey)
            switch result {
            case .failure(let error):
                if requestKey == self.activeKey { self.failed(error.localizedDescription, self.activeRevision) }
            case .success(let routes):
                let shape = routes.mainRoute.route.shape?.coordinates ?? []
                let validation = PlannedRouteGeometry.validate(coordinates, shape, tolerance: tolerance)
                guard validation.matches else {
                    if requestKey == self.activeKey { self.failed(validation.message(tolerance: tolerance), self.activeRevision) }
                    return
                }
                if self.cache.count >= 3, let old = self.cache.keys.first(where: { $0 != self.activeKey }) { self.cache.removeValue(forKey: old) }
                self.cache[requestKey] = routes
                if requestKey == self.activeKey { self.ready(routes, self.activeRevision) }
            }
        }
    }
}
