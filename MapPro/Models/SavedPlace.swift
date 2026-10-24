import Foundation
import CoreLocation
import MapKit

/// A lightweight, `Codable` snapshot of a place so favorites survive relaunches.
struct SavedPlace: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let categoryRawValue: String?
    let phoneNumber: String?
    let websiteURLString: String?
    let isDroppedPin: Bool
    let savedAt: Date

    init(place: Place) {
        self.id = place.id
        self.name = place.name
        self.address = place.address
        self.latitude = place.coordinate.latitude
        self.longitude = place.coordinate.longitude
        self.categoryRawValue = place.category?.rawValue
        self.phoneNumber = place.phoneNumber
        self.websiteURLString = place.websiteURL?.absoluteString
        self.isDroppedPin = place.isDroppedPin
        self.savedAt = Date()
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var place: Place {
        Place(
            name: name,
            address: address,
            coordinate: coordinate,
            category: categoryRawValue.map { MKPointOfInterestCategory(rawValue: $0) },
            phoneNumber: phoneNumber,
            websiteURL: websiteURLString.flatMap { URL(string: $0) },
            isDroppedPin: isDroppedPin
        )
    }
}
