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
        case navigation(CLLocationCoordinate2D, heading: CLLocationDirection)
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
    @Published var droppedPin: Place?

    // Navigation
    @Published var isNavigating = false
    @Published var navigationStepIndex = 0
    @Published var navigationRemainingDistance: CLLocationDistance = 0
    @Published var navigationRemainingTime: TimeInterval = 0
    @Published var navigationDistanceToManeuver: CLLocationDistance?
    @Published var speedKPH: Double = 0

    // Offline
    @Published var offlineMode = false
    @Published private(set) var networkAvailable = true

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
    private let geocoder = CLGeocoder()
    private var searchWorkItem: DispatchWorkItem?
    private var searchToken = UUID()
    private var currentSearch: MKLocalSearch?
    private var directionsToken = UUID()
    private var currentDirections: MKDirections?
    private var pinToken = UUID()
    private var offlineFavorites: [Place] = []
    private var networkCancellable: AnyCancellable?
    private var lastNavigationCameraUpdate = Date.distantPast
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

        networkAvailable = NetworkMonitor.shared.isOnline
        networkCancellable = NetworkMonitor.shared.onlinePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] online in
                self?.handleNetworkChange(online)
            }
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

    /// Everything that should appear on the map: search results, the persistent
    /// dropped pin, and any externally selected place (for example a favorite).
    var mapPins: [Place] {
        var pins = places

        if let droppedPin, !pins.contains(where: { $0.id == droppedPin.id }) {
            pins.append(droppedPin)
        }
        if let selectedPlace, !pins.contains(where: { $0.id == selectedPlace.id }) {
            pins.append(selectedPlace)
        }

        return pins
    }

    // MARK: - Offline state

    var isOffline: Bool {
        offlineMode || !networkAvailable
    }

    func updateOfflineFavorites(_ places: [Place]) {
        offlineFavorites = places
    }

    func toggleOfflineMode() {
        offlineMode.toggle()
        Haptics.tap()

        if offlineMode {
            searchToken = UUID()
            searchWorkItem?.cancel()
            currentSearch?.cancel()
            currentSearch = nil
            isSearching = false
            suggestions = []
            clearRoute()
            showToast("Offline mode on — saved and cached places only")
        } else if networkAvailable {
            showToast("Offline mode off")
        } else {
            showToast("Still offline — check your connection")
        }
    }

    private func handleNetworkChange(_ online: Bool) {
        let wasOffline = isOffline
        networkAvailable = online

        if online {
            if wasOffline && !offlineMode {
                showToast("Back online")
            }
            return
        }

        suggestions = []
        searchWorkItem?.cancel()
        currentSearch?.cancel()
        currentSearch = nil
        isSearching = false

        if !wasOffline {
            showToast("You're offline. Saved and cached places still work.")
        }
    }

    // MARK: - Navigation state

    var navigationInstruction: String {
        guard let step = currentNavigationStep else { return "Continue" }
        let instructions = step.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        return instructions.isEmpty ? "Continue" : instructions
    }

    var navigationManeuverSymbol: String {
        ManeuverSymbol.symbol(for: navigationInstruction)
    }

    var navigationNextInstruction: String? {
        guard let route = selectedRoute?.route else { return nil }
        let start = navigationStepIndex + 1
        guard start < route.steps.count else { return nil }

        for step in route.steps[start...] {
            let instructions = step.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
            if !instructions.isEmpty {
                return instructions
            }
        }
        return nil
    }

    var navigationDistanceToManeuverText: String {
        guard let distance = navigationDistanceToManeuver else { return "—" }
        return Formatters.distance(distance)
    }

    var navigationRemainingTimeText: String {
        Formatters.duration(navigationRemainingTime)
    }

    var navigationRemainingDistanceText: String {
        Formatters.distance(navigationRemainingDistance)
    }

    var navigationArrivalText: String {
        Formatters.arrivalTime(navigationRemainingTime)
    }

    var navigationStepProgressText: String {
        guard let route = selectedRoute?.route, !route.steps.isEmpty else { return "" }
        return "Step \(min(navigationStepIndex + 1, route.steps.count)) of \(route.steps.count)"
    }

    private var currentNavigationStep: MKRoute.Step? {
        guard let route = selectedRoute?.route,
              navigationStepIndex >= 0,
              navigationStepIndex < route.steps.count else { return nil }
        return route.steps[navigationStepIndex]
    }

    // MARK: - Search

    func updateSearchQuery(_ query: String) {
        searchWorkItem?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isOffline, trimmed.count >= 2 else {
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

        if let coordinate = CoordinateParser.parse(trimmed) {
            searchCoordinate(coordinate)
            return
        }

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
        if isOffline {
            performOfflineSearch(query)
            return
        }

        searchWorkItem?.cancel()
        searchToken = UUID()
        let token = searchToken
        currentSearch?.cancel()

        lastQuery = query
        isSearching = true
        showSearchArea = false
        suggestions = []
        selectedPlace = nil
        clearDroppedPin()
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
                    SearchCache.shared.save(query: query, places: found)
                    Haptics.success()
                }
            }
        }
    }

    private func performOfflineSearch(_ query: String) {
        searchToken = UUID()
        searchWorkItem?.cancel()
        currentSearch?.cancel()
        currentSearch = nil
        isSearching = false
        showSearchArea = false
        suggestions = []
        selectedPlace = nil
        clearDroppedPin()
        clearRoute()

        lastQuery = query
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        var found = SearchCache.shared.results(for: query)
        let favorites = offlineFavorites.filter { place in
            place.name.localizedCaseInsensitiveContains(trimmed)
                || place.address.localizedCaseInsensitiveContains(trimmed)
                || place.categoryName.localizedCaseInsensitiveContains(trimmed)
                || place.coordinateText.contains(trimmed)
        }
        for favorite in favorites where !found.contains(where: { $0.id == favorite.id }) {
            found.append(favorite)
        }

        places = found

        if found.isEmpty {
            showToast("Offline — no saved or cached places for \"\(query)\".")
        } else {
            fitToResults()
            showToast("Offline — showing \(found.count) saved or cached \(found.count == 1 ? "place" : "places").")
            Haptics.success()
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
        if place.isDroppedPin {
            droppedPin = place
        }
        guard selectedPlace?.id != place.id else { return }
        selectedPlace = place
        cameraCommand = CameraCommand(target: .coordinate(place.coordinate, altitude: 1100))
        Haptics.select()
    }

    func clearSelection() {
        selectedPlace = nil
    }

    // MARK: - Coordinates and dropped pins

    /// Drops a pin at an arbitrary coordinate and reverse geocodes a street address.
    func dropPin(at coordinate: CLLocationCoordinate2D, announce: Bool = true) {
        geocoder.cancelGeocode()
        pinToken = UUID()

        let pin = Place(
            name: "Dropped pin",
            address: Formatters.coordinate(coordinate),
            coordinate: coordinate,
            isDroppedPin: true
        )

        droppedPin = pin
        selectedPlace = pin
        showSearchArea = false
        clearRoute()
        Haptics.select()

        if announce {
            showToast("Pin dropped at \(Formatters.coordinate(coordinate))")
        }

        if !isOffline {
            reverseGeocode(pin)
        }
    }

    /// Moves the existing dropped pin, for example after the user drags it.
    func moveDroppedPin(to coordinate: CLLocationCoordinate2D) {
        guard droppedPin != nil else { return }

        geocoder.cancelGeocode()
        pinToken = UUID()

        let pin = Place(
            name: "Dropped pin",
            address: Formatters.coordinate(coordinate),
            coordinate: coordinate,
            isDroppedPin: true
        )

        droppedPin = pin
        selectedPlace = pin
        showSearchArea = false
        clearRoute()
        Haptics.select()
        showToast("Pin moved to \(Formatters.coordinate(coordinate))")

        if !isOffline {
            reverseGeocode(pin)
        }
    }

    func searchCoordinate(_ coordinate: CLLocationCoordinate2D) {
        searchToken = UUID()
        searchWorkItem?.cancel()
        currentSearch?.cancel()
        currentSearch = nil
        isSearching = false
        suggestions = []
        places = []
        showSearchArea = false
        lastQuery = CoordinateParser.format(coordinate)
        selectedPlace = nil
        clearRoute()
        dropPin(at: coordinate, announce: false)
        cameraCommand = CameraCommand(target: .coordinate(coordinate, altitude: 1200))
        showToast("Showing \(Formatters.coordinate(coordinate))")
    }

    func clearDroppedPin() {
        geocoder.cancelGeocode()
        pinToken = UUID()

        if let droppedPin, selectedPlace?.id == droppedPin.id {
            selectedPlace = nil
        }
        droppedPin = nil
    }

    private func reverseGeocode(_ pin: Place) {
        let token = UUID()
        pinToken = token
        let location = CLLocation(latitude: pin.coordinate.latitude, longitude: pin.coordinate.longitude)

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                guard self.pinToken == token,
                      let current = self.droppedPin,
                      current.id == pin.id,
                      let mark = placemarks?.first else { return }

                let address = Place.addressText(
                    from: mark,
                    fallback: Formatters.coordinate(pin.coordinate)
                )
                let updated = Place(
                    name: "Dropped pin",
                    address: address,
                    coordinate: pin.coordinate,
                    isDroppedPin: true
                )

                self.droppedPin = updated
                if self.selectedPlace?.id == updated.id {
                    self.selectedPlace = updated
                }
            }
        }
    }

    // MARK: - Directions

    func prepareDirections(to destination: Place) {
        directionsDestination = destination
        routeOptions = []
        selectedRouteID = nil
        routeError = nil
        stopNavigation(announce: false)
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

        guard !isOffline else {
            currentDirections?.cancel()
            currentDirections = nil
            isRouting = false
            routeOptions = []
            selectedRouteID = nil
            routeError = "Directions need an internet connection. Saved places and cached results still work offline."
            Haptics.warning()
            return
        }

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
        stopNavigation(announce: false)
        directionsToken = UUID()
        currentDirections?.cancel()
        currentDirections = nil
        routeOptions = []
        selectedRouteID = nil
        isRouting = false
        routeError = nil
    }

    func endDirections() {
        stopNavigation(announce: false)
        clearRoute()
        directionsDestination = nil
    }

    /// Starts an in-app guidance session along the selected route.
    func startNavigation() {
        guard let option = selectedRoute else {
            showToast("Choose a route first.")
            return
        }

        isNavigating = true
        navigationStepIndex = 0
        navigationDistanceToManeuver = option.route.steps.first?.distance
        navigationRemainingDistance = option.route.distance
        navigationRemainingTime = option.route.expectedTravelTime
        lastNavigationCameraUpdate = .distantPast

        updateNavigationMetrics(for: nil)

        let start = option.route.polyline.firstCoordinate
            ?? option.route.steps.first?.polyline.firstCoordinate
            ?? userCoordinate
            ?? directionsDestination?.coordinate

        if let start {
            let heading = userCoordinate != nil ? self.heading : 0
            cameraCommand = CameraCommand(target: .navigation(start, heading: heading))
        }

        showToast("Navigation started")
        Haptics.success()
    }

    /// Hands the current destination to the system Maps app for voice guidance.
    func openInAppleMaps() {
        guard let destination = directionsDestination else { return }
        let options: [String: Any] = [MKLaunchOptionsDirectionsModeKey: travelMode.launchMode]
        _ = destination.mapItem.openInMaps(launchOptions: options)
    }

    func stopNavigation(announce: Bool = true) {
        guard isNavigating else { return }

        isNavigating = false
        navigationStepIndex = 0
        navigationRemainingDistance = 0
        navigationRemainingTime = 0
        navigationDistanceToManeuver = nil
        lastNavigationCameraUpdate = .distantPast

        if announce {
            showToast("Navigation ended")
            Haptics.tap()
        }
    }

    // MARK: - Navigation progress

    private func updateNavigation(with location: CLLocation) {
        guard isNavigating else { return }

        updateNavigationMetrics(for: location)
        followNavigation(with: location)

        if let destination = directionsDestination {
            let destinationLocation = CLLocation(
                latitude: destination.coordinate.latitude,
                longitude: destination.coordinate.longitude
            )
            if location.distance(from: destinationLocation) < 35 {
                finishNavigation()
            }
        }
    }

    private func updateNavigationMetrics(for location: CLLocation?) {
        guard let route = selectedRoute?.route else {
            navigationRemainingDistance = 0
            navigationRemainingTime = 0
            navigationDistanceToManeuver = nil
            return
        }

        let steps = route.steps
        guard !steps.isEmpty else {
            navigationRemainingDistance = route.distance
            navigationRemainingTime = route.expectedTravelTime
            navigationDistanceToManeuver = route.distance
            return
        }

        if let location {
            advanceStepIfNeeded(with: location, steps: steps)
        }

        let index = min(max(navigationStepIndex, 0), steps.count - 1)
        var currentStepRemaining = steps[index].distance
        var remaining = currentStepRemaining

        if let location, let start = steps[index].polyline.firstCoordinate {
            let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
            let traveled = location.distance(from: startLocation)
            currentStepRemaining = max(0, steps[index].distance - traveled)
            remaining = currentStepRemaining
        }

        if index + 1 < steps.count {
            for stepIndex in (index + 1)..<steps.count {
                remaining += steps[stepIndex].distance
            }
        }

        navigationRemainingDistance = remaining
        navigationDistanceToManeuver = currentStepRemaining

        let ratio = route.distance > 0 ? min(1, max(0, remaining / route.distance)) : 0
        navigationRemainingTime = max(0, route.expectedTravelTime * ratio)
    }

    private func advanceStepIfNeeded(with location: CLLocation, steps: [MKRoute.Step]) {
        guard navigationStepIndex >= 0, navigationStepIndex < steps.count else { return }

        let searchEnd = min(steps.count - 1, navigationStepIndex + 4)
        var bestIndex = navigationStepIndex
        var bestDistance = CLLocationDistance.greatestFiniteMagnitude

        for index in navigationStepIndex...searchEnd {
            guard let start = steps[index].polyline.firstCoordinate else { continue }
            let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
            let distance = location.distance(from: startLocation)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }

        if bestDistance < 20, bestIndex > navigationStepIndex {
            navigationStepIndex = bestIndex
        }
    }

    private func followNavigation(with location: CLLocation) {
        let now = Date()
        guard now.timeIntervalSince(lastNavigationCameraUpdate) > 1.2 else { return }
        lastNavigationCameraUpdate = now

        let heading = location.course >= 0 ? location.course : 0
        cameraCommand = CameraCommand(target: .navigation(location.coordinate, heading: heading))
    }

    private func finishNavigation() {
        let name = directionsDestination?.name ?? "your destination"
        stopNavigation(announce: false)
        clearRoute()
        directionsDestination = nil
        showToast("You've arrived at \(name)")
        Haptics.success()
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
        speedKPH = location.speed >= 0 ? location.speed * 3.6 : 0

        if isNavigating {
            updateNavigation(with: location)
        } else {
            focusOnUserIfNeeded()
        }
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
