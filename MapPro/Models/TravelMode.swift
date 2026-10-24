import MapKit

enum TravelMode: String, CaseIterable, Identifiable {
    case automobile
    case walking
    case transit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automobile: return "Drive"
        case .walking: return "Walk"
        case .transit: return "Transit"
        }
    }

    var symbolName: String {
        switch self {
        case .automobile: return "car.fill"
        case .walking: return "figure.walk"
        case .transit: return "tram.fill"
        }
    }

    var transportType: MKDirectionsTransportType {
        switch self {
        case .automobile: return .automobile
        case .walking: return .walking
        case .transit: return .transit
        }
    }

    var launchMode: String {
        switch self {
        case .automobile: return MKLaunchOptionsDirectionsModeDriving
        case .walking: return MKLaunchOptionsDirectionsModeWalking
        case .transit: return MKLaunchOptionsDirectionsModeTransit
        }
    }
}
