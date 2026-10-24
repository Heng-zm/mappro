import MapKit

struct RouteOption: Identifiable {
    let id = UUID()
    let route: MKRoute
    let mode: TravelMode

    var timeText: String {
        Formatters.duration(route.expectedTravelTime)
    }

    var distanceText: String {
        Formatters.distance(route.distance)
    }

    var arrivalText: String {
        Formatters.arrivalTime(route.expectedTravelTime)
    }

    var viaText: String {
        route.name.isEmpty ? "Suggested route" : "via \(route.name)"
    }

    var steps: [MKRoute.Step] {
        route.steps.filter { !$0.instructions.isEmpty }
    }
}
