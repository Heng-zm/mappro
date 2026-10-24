import Foundation
import Combine
import MapKit
import CoreLocation
import UIKit

struct CameraCommand {
    enum Target {
        case coordinate(CLLocationCoordinate2D, altitude: CLLocationDistance)
        case region(MKCoordinateRegion)
        case rect(MKMapRect, padding: UIEdgeInsets)
        case resetNorth
    }

    let id = UUID()
    let target: Target
}

final class MapEngine: NSObject, ObservableObject {
    static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
    )

    // Search
    @Published var places: [Place] = []
    @Published var suggestions: [SearchSuggestion] = []
    @Published var isSearching = false
    @Published var lastQuery = ""
    @Published var showSearchArea = false

    // Selection
    @Published var selectedPlace: Place?

    // Directions
    @Published var directionsDestination: Place?
    @Published var routeOptions: [RouteOption] = []
    @Published var selectedRouteID: UUID?
    @Published var travelMode: TravelMode = .automobile
    @Published var isRouting = false
    @Published var routeError: String?

    // Map presentation
    @Published var mapLayer: MapLayer = .standard
    @Published var trafficEnabled = false
    @Published var is3D = false
    @Published var heading: CLLocationDirection = 0
    @Published var cameraCommand: CameraCommand?

    // Location
    @Published var userCoordinate: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var mapRegion: MKCoordinateRegion = MapEngine.defaultRegion

    // Feedback
    @Published var toast: String?

    private let locationManager = CLLocationManager()
    private let completer = MKLocalSearchCompleter()
    private var searchWorkItem: DispatchWorkItem?
    private var searchToken = UUID()
    private var currentSearch: MKLocalSearch?
    private var directionsToken = UUID()
    private var currentDirections: MKDirections?
    private var hasCenteredOnUser = false
    private var hasStarted = false
    private var toastWorkItem: DispatchWorkItem?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5

        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
    }

    // MARK: - Lifecycle

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        authorizationStatus = locationManager.authorizationStatus

        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }

    var isLocationAuthorized: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }

    var isLocationDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    var selectedRoute: RouteOption? {
        guard let selectedRouteID else { return nil }
        return routeOptions.first { $0.id == selectedRouteID }
    }

    // MARK: - Search

    func updateSearchQuery(_ query: String) {
        searchWorkItem?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            suggestions = []
            return
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.completer.region = self.mapRegion
            self.completer.queryFragment = trimmed
        }
        searchWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
    }

    func clearSuggestions() {
        searchWorkItem?.cancel()
        suggestions = []
    }

    func search(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.region = mapRegion
        request.resultTypes = [.pointOfInterest, .address]
        performSearch(request, query: trimmed)
    }

    func search(suggestion: SearchSuggestion) {
        guard let completion = suggestion.completion else {
            search(text: suggestion.title)
            return
        }
        let request = MKLocalSearch.Request(completion: completion)
        request.region = mapRegion
        performSearch(request, query: suggestion.title)
    }

    func searchNearby(_ category: ExploreCategory) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = category.query
        request.region = MKCoordinateRegion(
            center: mapRegion.center,
            latitudinalMeters: 6000,
            longitudinalMeters: 6000
        )
        request.resultTypes = [.pointOfInterest]
        performSearch(request, query: category.title)
    }

    func searchHere() {
        guard !lastQuery.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = lastQuery
        request.region = mapRegion
        request.resultTypes = [.pointOfInterest, .address]
        performSearch(request, query: lastQuery)
    }

    private func performSearch(_ request: MKLocalSearch.Request, query: String) {
        searchWorkItem?.cancel()
        searchToken = UUID()
        let token = searchToken
        currentSearch?.cancel()

        lastQuery = query
        isSearching = true
        showSearchArea = false
        suggestions = []
        selectedPlace = nil
        clearRoute()

        let search = MKLocalSearch(request: request)
        currentSearch = search
        search.start { [weak self] response, error in
            guard let self else { return }
            DispatchQueue.main.async {
                guard self.searchToken == token else { return }
                self.isSearching = false
                self.currentSearch = nil

                if let error {
                    self.places = []
                    self.showToast(error.localizedDescription)
                    return
                }

                guard let response else {
                    self.places = []
                    self.showToast("No results found for \"\(query)\".")
                    return
                }

                let found = response.mapItems.map { Place(mapItem: $0) }
                self.places = found
                self.fitToResults()

                if found.isEmpty {
                    self.showToast("No results found for \"\(query)\".")
                } else {
                    Haptics.success()
                }
            }
        }
    }

    func cancelSearch() {
        searchToken = UUID()
        searchWorkItem?.cancel()
        currentSearch?.cancel()
        currentSearch = nil
        isSearching = false
        suggestions = []
        showSearchArea = false
    }

    private func fitToResults() {
        guard !places.isEmpty else { return }

        if places.count == 1, let place = places.first {
            cameraCommand = CameraCommand(target: .coordinate(place.coordinate, altitude: 1200))
            return
        }

        var minLat = 90.0
        var maxLat = -90.0
        var minLon = 180.0
        var maxLon = -180.0

        for place in places {
            minLat = min(minLat, place.coordinate.latitude)
            maxLat = max(maxLat, place.coordinate.latitude)
            minLon = min(minLon, place.coordinate.longitude)
            maxLon = max(maxLon, place.coordinate.longitude)
        }

        guard minLat <= maxLat, minLon <= maxLon else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let latitudeDelta = min(max((maxLat - minLat) * 1.6, 0.006), 90)
        let longitudeDelta = min(max((maxLon - minLon) * 1.6, 0.006), 180)
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
        cameraCommand = CameraCommand(target: .region(region))
    }

    // MARK: - Selection

    func select(place: Place) {
        guard selectedPlace?.id != place.id else { return }
        selectedPlace = place
        cameraCommand = CameraCommand(target: .coordinate(place.coordinate, altitude: 1100))
        Haptics.select()
    }

    func clearSelection() {
        selectedPlace = nil
    }

    // MARK: - Directions

    func prepareDirections(to destination: Place) {
        directionsDestination = destination
        routeOptions = []
        selectedRouteID = nil
        routeError = nil
        requestDirections()
    }

    func setTravelMode(_ mode: TravelMode) {
        guard travelMode != mode else { return }
        travelMode = mode
        if directionsDestination != nil {
            requestDirections()
        }
    }

    func requestDirections() {
        guard let destination = directionsDestination else { return }

        let origin = userCoordinate ?? mapRegion.center
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = destination.mapItem
        request.transportType = travelMode.transportType
        request.requestsAlternateRoutes = travelMode == .automobile

        currentDirections?.cancel()
        directionsToken = UUID()
        let token = directionsToken
        isRouting = true
        routeError = nil

        let directions = MKDirections(request: request)
        currentDirections = directions
        directions.calculate { [weak self] response, error in
            guard let self else { return }
            DispatchQueue.main.async {
                guard self.directionsToken == token else { return }
                self.isRouting = false
                self.currentDirections = nil

                if let error {
                    self.routeOptions = []
                    self.selectedRouteID = nil
                    self.routeError = error.localizedDescription
                    Haptics.warning()
                    return
                }

                guard let response else {
                    self.routeOptions = []
                    self.selectedRouteID = nil
                    self.routeError = "No route available."
                    Haptics.warning()
                    return
                }

                let options = response.routes.map { RouteOption(route: $0, mode: self.travelMode) }
                self.routeOptions = options
                self.selectedRouteID = options.first?.id

                if options.isEmpty {
                    self.routeError = "No route available for this mode."
                    Haptics.warning()
                } else {
                    Haptics.success()
                }
            }
        }
    }

    func selectRoute(_ option: RouteOption) {
        guard selectedRouteID != option.id else { return }
        selectedRouteID = option.id
        Haptics.tap()
    }

    func clearRoute() {
        directionsToken = UUID()
        currentDirections?.cancel()
        currentDirections = nil
        routeOptions = []
        selectedRouteID = nil
        isRouting = false
        routeError = nil
    }

    func endDirections() {
        clearRoute()
        directionsDestination = nil
    }

    func startNavigation() {
        guard let destination = directionsDestination else { return }
        let options: [String: Any] = [MKLaunchOptionsDirectionsModeKey: travelMode.launchMode]
        _ = destination.mapItem.openInMaps(launchOptions: options)
    }

    // MARK: - Map controls

    func recenterOnUser() {
        guard let userCoordinate else {
            switch authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                showToast("Location access is off. Enable it in Settings.")
            default:
                showToast("Finding your location…")
                locationManager.startUpdatingLocation()
            }
            return
        }
        cameraCommand = CameraCommand(target: .coordinate(userCoordinate, altitude: 900))
        Haptics.tap()
    }

    func setLayer(_ layer: MapLayer) {
        guard mapLayer != layer else { return }
        mapLayer = layer
        Haptics.tap()
    }

    func toggleTraffic() {
        trafficEnabled.toggle()
        Haptics.tap()
    }

    func toggle3D() {
        is3D.toggle()
        Haptics.select()
    }

    func resetNorth() {
        cameraCommand = CameraCommand(target: .resetNorth)
        Haptics.tap()
    }

    func updateVisibleRegion(_ region: MKCoordinateRegion) {
        mapRegion = region
    }

    func updateHeading(_ newHeading: CLLocationDirection) {
        if abs(newHeading - heading) > 1 {
            heading = newHeading
        }
    }

    // MARK: - Feedback

    func showToast(_ message: String) {
        toastWorkItem?.cancel()
        toast = message

        let work = DispatchWorkItem { [weak self] in
            self?.toast = nil
        }
        toastWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2, execute: work)
    }

    func dismissToast() {
        toastWorkItem?.cancel()
        toast = nil
    }

    // MARK: - Private helpers

    private func focusOnUserIfNeeded() {
        guard !hasCenteredOnUser, let coordinate = userCoordinate else { return }
        hasCenteredOnUser = true
        cameraCommand = CameraCommand(target: .coordinate(coordinate, altitude: 1000))
    }
}

// MARK: - CLLocationManagerDelegate

extension MapEngine: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if isLocationAuthorized {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        userCoordinate = location.coordinate
        focusOnUserIfNeeded()
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension MapEngine: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let mapped = completer.results.prefix(7).map { SearchSuggestion(completion: $0) }
        DispatchQueue.main.async {
            self.suggestions = Array(mapped)
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.suggestions = []
        }
    }
}
