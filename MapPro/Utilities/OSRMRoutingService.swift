import Foundation
import CoreLocation
import MapKit

/// A route returned by an OpenStreetMap routing server.
struct OSRMRoute {
    let distance: CLLocationDistance
    let duration: TimeInterval
    let coordinates: [CLLocationCoordinate2D]
    let steps: [OSRMRouteStep]
    let name: String
}

struct OSRMRouteStep {
    let instructions: String
    let distance: CLLocationDistance
    let coordinates: [CLLocationCoordinate2D]
}

enum OSRMRoutingError: LocalizedError {
    case unsupportedMode
    case invalidURL
    case network
    case busy
    case server(String)
    case noRoute
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unsupportedMode:
            return "Transit directions aren't available in this region yet. Try Drive or Walk."
        case .invalidURL:
            return "The routing service couldn't build this request. Try a different destination."
        case .network:
            return "Couldn't reach the OpenStreetMap routing service. Check your connection and try again."
        case .busy:
            return "The OpenStreetMap routing service is busy right now. Try again in a moment."
        case .server(let message):
            return message
        case .noRoute:
            return "No route available for this trip. Try a different destination or travel mode."
        case .invalidResponse:
            return "The routing service returned an unexpected response. Try again."
        }
    }
}

/// Free, keyless OpenStreetMap routing used only when Apple's `MKDirections`
/// cannot return a route (for example in regions without Apple driving coverage).
///
/// These are public community servers with rate limits. They are fine as a
/// fallback for personal use, but are not a production-grade routing backend.
final class OSRMRoutingService {
    static let shared = OSRMRoutingService()

    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        configuration.httpAdditionalHeaders = ["Accept": "application/json"]
        session = URLSession(configuration: configuration)
    }

    @discardableResult
    func calculateRoutes(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        mode: TravelMode,
        completion: @escaping (Result<[OSRMRoute], OSRMRoutingError>) -> Void
    ) -> URLSessionDataTask? {
        guard mode == .automobile || mode == .walking else {
            completion(.failure(.unsupportedMode))
            return nil
        }

        guard let url = Self.url(from: origin, to: destination, mode: mode) else {
            completion(.failure(.invalidURL))
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(
            "MapPro/1.3.0 (iOS; https://github.com/Heng-zm/mappro)",
            forHTTPHeaderField: "User-Agent"
        )

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error as? URLError, error.code == .cancelled {
                return
            }

            if error != nil {
                completion(.failure(.network))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            if httpResponse.statusCode == 429 {
                completion(.failure(.busy))
                return
            }

            guard (200...299).contains(httpResponse.statusCode), let data else {
                completion(.failure(.server("The routing service is unavailable right now. Try again in a moment.")))
                return
            }

            do {
                let payload = try JSONDecoder().decode(OSRMResponse.self, from: data)

                guard payload.code == "Ok" else {
                    if payload.code == "NoRoute" {
                        completion(.failure(.noRoute))
                    } else {
                        completion(.failure(.server(payload.message ?? "No route available for this trip.")))
                    }
                    return
                }

                let routes = (payload.routes ?? []).compactMap(Self.makeRoute)
                guard !routes.isEmpty else {
                    completion(.failure(.noRoute))
                    return
                }

                completion(.success(routes))
            } catch {
                completion(.failure(.invalidResponse))
            }
        }

        task.resume()
        return task
    }

    // MARK: - Request

    private static func url(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        mode: TravelMode
    ) -> URL? {
        let base: String
        switch mode {
        case .automobile:
            base = "https://router.project-osrm.org/route/v1/driving/"
        case .walking:
            base = "https://routing.openstreetmap.de/routed-foot/route/v1/foot/"
        case .transit:
            return nil
        }

        let points = "\(coordinateString(origin));\(coordinateString(destination))"
        let alternatives = mode == .automobile ? "true" : "false"
        let query = "overview=full&geometries=geojson&steps=true&alternatives=\(alternatives)"
        return URL(string: base + points + "?" + query)
    }

    private static func coordinateString(_ coordinate: CLLocationCoordinate2D) -> String {
        // OSRM expects longitude first. POSIX locale keeps the decimal point.
        String(
            format: "%.6f,%.6f",
            locale: Locale(identifier: "en_US_POSIX"),
            coordinate.longitude,
            coordinate.latitude
        )
    }

    // MARK: - Response mapping

    private static func makeRoute(from payload: OSRMRoutePayload) -> OSRMRoute? {
        let payloadSteps = payload.legs.flatMap { $0.steps }

        var coordinates = payload.geometry?.coordinates.compactMap(makeCoordinate) ?? []
        if coordinates.count < 2 {
            coordinates = payloadSteps.flatMap { step in
                step.geometry?.coordinates.compactMap(makeCoordinate) ?? []
            }
        }

        guard coordinates.count >= 2 else { return nil }

        var steps: [OSRMRouteStep] = []
        for (index, payloadStep) in payloadSteps.enumerated() {
            var stepCoordinates = payloadStep.geometry?.coordinates.compactMap(makeCoordinate) ?? []

            if stepCoordinates.count < 2 {
                let start = makeCoordinate(payloadStep.maneuver.location)
                let nextLocation = payloadSteps.indices.contains(index + 1)
                    ? makeCoordinate(payloadSteps[index + 1].maneuver.location)
                    : coordinates.last
                stepCoordinates = [start, nextLocation].compactMap { $0 }
            }

            guard let first = stepCoordinates.first else { continue }
            if stepCoordinates.count == 1 {
                stepCoordinates.append(first)
            }

            steps.append(
                OSRMRouteStep(
                    instructions: instruction(for: payloadStep),
                    distance: max(0, payloadStep.distance),
                    coordinates: stepCoordinates
                )
            )
        }

        if steps.isEmpty {
            steps = [
                OSRMRouteStep(
                    instructions: "Follow the route",
                    distance: max(0, payload.distance),
                    coordinates: coordinates
                )
            ]
        }

        return OSRMRoute(
            distance: max(0, payload.distance),
            duration: max(0, payload.duration),
            coordinates: coordinates,
            steps: steps,
            name: mostSignificantRoadName(in: payloadSteps)
        )
    }

    private static func makeCoordinate(_ values: [Double]) -> CLLocationCoordinate2D? {
        guard values.count >= 2 else { return nil }
        let longitude = values[0]
        let latitude = values[1]
        guard latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude),
              (-180...180).contains(longitude) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func mostSignificantRoadName(in steps: [OSRMStepPayload]) -> String {
        var distanceByRoad: [String: CLLocationDistance] = [:]

        for step in steps {
            guard let road = roadLabel(for: step) else { continue }
            distanceByRoad[road, default: 0] += max(0, step.distance)
        }

        return distanceByRoad.max { $0.value < $1.value }?.key ?? ""
    }

    private static func roadLabel(for step: OSRMStepPayload) -> String? {
        if let name = step.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        if let ref = step.ref?.trimmingCharacters(in: .whitespacesAndNewlines), !ref.isEmpty {
            return ref
        }
        return nil
    }

    // MARK: - Instructions

    private static func instruction(for step: OSRMStepPayload) -> String {
        let type = step.maneuver.type.lowercased()
        let modifier = step.maneuver.modifier?.lowercased()
        let road = roadLabel(for: step)
        let onto = road.map { " onto \($0)" } ?? ""

        switch type {
        case "depart":
            return road.map { "Head out on \($0)" } ?? "Head out"

        case "arrive":
            return "Arrive at your destination"

        case "turn":
            if modifier == nil || modifier == "straight" {
                return "Continue\(onto)"
            }
            if modifier == "uturn" {
                return "Make a U-turn\(onto)"
            }
            return "Turn \(modifier!)\(onto)"

        case "new name", "continue":
            return "Continue\(onto)"

        case "merge":
            return modifier.map { "Merge \($0)\(onto)" } ?? "Merge\(onto)"

        case "fork":
            return modifier.map { "Keep \($0)\(onto)" } ?? "Keep straight\(onto)"

        case "end of road":
            return modifier.map { "Turn \($0)\(onto)" } ?? "Turn\(onto)"

        case "roundabout", "rotary":
            let exit = step.maneuver.exit.map { " and take exit \($0)" } ?? ""
            return "At the roundabout\(exit)\(onto)"

        case "roundabout turn":
            return modifier.map { "At the roundabout, turn \($0)\(onto)" }
                ?? "At the roundabout, continue\(onto)"

        case "exit roundabout", "exit rotary":
            return "Exit the roundabout\(onto)"

        case "on ramp":
            return "Take the ramp\(onto)"

        case "off ramp":
            return "Take the exit\(onto)"

        case "use lane":
            return modifier.map { "Use the \($0) lane" } ?? "Use the indicated lane"

        default:
            return road.map { "Continue onto \($0)" } ?? "Continue"
        }
    }
}

// MARK: - RouteOption bridge

extension RouteOption {
    init(osrm route: OSRMRoute, mode: TravelMode) {
        let polyline = MKPolyline(
            coordinates: route.coordinates,
            count: route.coordinates.count
        )

        let steps = route.steps.map { step in
            RouteStep(
                instructions: step.instructions,
                distance: step.distance,
                polyline: MKPolyline(coordinates: step.coordinates, count: step.coordinates.count)
            )
        }

        self.init(
            mode: mode,
            distance: route.distance,
            expectedTravelTime: route.duration,
            name: route.name,
            polyline: polyline,
            steps: steps,
            source: .openStreetMap
        )
    }
}

// MARK: - OSRM JSON

private struct OSRMResponse: Decodable {
    let code: String
    let message: String?
    let routes: [OSRMRoutePayload]?
}

private struct OSRMRoutePayload: Decodable {
    let distance: Double
    let duration: Double
    let geometry: OSRMGeometry?
    let legs: [OSRMLeg]
}

private struct OSRMLeg: Decodable {
    let steps: [OSRMStepPayload]
}

private struct OSRMStepPayload: Decodable {
    let distance: Double
    let duration: Double
    let name: String?
    let ref: String?
    let geometry: OSRMGeometry?
    let maneuver: OSRMManeuver
}

private struct OSRMManeuver: Decodable {
    let type: String
    let modifier: String?
    let exit: Int?
    let location: [Double]
}

private struct OSRMGeometry: Decodable {
    let coordinates: [[Double]]
}
