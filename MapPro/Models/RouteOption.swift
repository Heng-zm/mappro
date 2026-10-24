import Foundation
import MapKit

/// Where a route was calculated. Apple Maps is preferred; OpenStreetMap is the
/// fallback for regions where Apple's routing service has no coverage.
enum RouteSource: Equatable {
    case appleMaps
    case openStreetMap

    var displayName: String {
        switch self {
        case .appleMaps: return "Apple Maps"
        case .openStreetMap: return "OpenStreetMap"
        }
    }

    var attributionText: String? {
        switch self {
        case .appleMaps: return nil
        case .openStreetMap: return "Route data © OpenStreetMap contributors"
        }
    }
}

/// A single maneuver that works with both MapKit and OpenStreetMap routes.
struct RouteStep {
    let instructions: String
    let distance: CLLocationDistance
    let polyline: MKPolyline
}

struct RouteOption: Identifiable {
    let id = UUID()
    let mode: TravelMode
    let distance: CLLocationDistance
    let expectedTravelTime: TimeInterval
    let name: String
    let polyline: MKPolyline
    let steps: [RouteStep]
    let source: RouteSource

    init(route: MKRoute, mode: TravelMode) {
        self.mode = mode
        self.distance = route.distance
        self.expectedTravelTime = route.expectedTravelTime
        self.name = route.name
        self.polyline = route.polyline
        self.steps = route.steps
            .filter { !$0.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map {
                RouteStep(
                    instructions: $0.instructions,
                    distance: $0.distance,
                    polyline: $0.polyline
                )
            }
        self.source = .appleMaps
    }

    init(
        mode: TravelMode,
        distance: CLLocationDistance,
        expectedTravelTime: TimeInterval,
        name: String,
        polyline: MKPolyline,
        steps: [RouteStep],
        source: RouteSource
    ) {
        self.mode = mode
        self.distance = distance
        self.expectedTravelTime = expectedTravelTime
        self.name = name
        self.polyline = polyline
        self.steps = steps
        self.source = source
    }

    var timeText: String {
        Formatters.duration(expectedTravelTime)
    }

    var distanceText: String {
        Formatters.distance(distance)
    }

    var arrivalText: String {
        Formatters.arrivalTime(expectedTravelTime)
    }

    var viaText: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Suggested route" : "via \(trimmed)"
    }
}
