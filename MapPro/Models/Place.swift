import Foundation
import MapKit
import CoreLocation
import SwiftUI

struct Place: Identifiable, Equatable {
    let id: String
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let category: MKPointOfInterestCategory?
    let phoneNumber: String?
    let websiteURL: URL?
    let mapItem: MKMapItem

    init(mapItem: MKMapItem) {
        let mark = mapItem.placemark
        let resolvedName = mapItem.name ?? mark.name ?? "Unnamed place"
        let coordinate = mark.coordinate

        var parts: [String] = []
        if let number = mark.subThoroughfare, let street = mark.thoroughfare {
            parts.append("\(number) \(street)")
        } else if let street = mark.thoroughfare {
            parts.append(street)
        }
        if let locality = mark.locality, !locality.isEmpty {
            parts.append(locality)
        }
        if let area = mark.administrativeArea, !area.isEmpty, area != (mark.locality ?? "") {
            parts.append(area)
        }

        self.id = "\(resolvedName)|\(String(format: "%.5f", coordinate.latitude))|\(String(format: "%.5f", coordinate.longitude))"
        self.name = resolvedName
        self.address = parts.isEmpty ? "Address unavailable" : parts.joined(separator: ", ")
        self.coordinate = coordinate
        self.category = mapItem.pointOfInterestCategory
        self.phoneNumber = mapItem.phoneNumber
        self.websiteURL = mapItem.url
        self.mapItem = mapItem
    }

    var categoryName: String {
        category?.mapLabel ?? "Place"
    }

    var symbolName: String {
        category?.symbolName ?? "mappin.and.ellipse"
    }

    var tint: Color {
        category?.tint ?? AppTheme.blue
    }

    var shareURL: URL {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "q", value: name)
        ]
        return components?.url ?? URL(string: "https://maps.apple.com")!
    }

    var phoneURL: URL? {
        guard let phoneNumber else { return nil }
        let allowed = phoneNumber.filter { $0.isNumber || $0 == "+" }
        guard !allowed.isEmpty else { return nil }
        return URL(string: "tel://\(allowed)")
    }

    func distanceText(from origin: CLLocationCoordinate2D?) -> String? {
        guard let origin else { return nil }
        let here = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let there = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return Formatters.distance(here.distance(from: there))
    }

    static func == (lhs: Place, rhs: Place) -> Bool {
        lhs.id == rhs.id &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}
