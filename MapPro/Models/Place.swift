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
    let isDroppedPin: Bool

    init(mapItem: MKMapItem) {
        let mark = mapItem.placemark
        let resolvedName = mapItem.name ?? mark.name ?? "Unnamed place"
        let coordinate = mark.coordinate

        self.id = "\(resolvedName)|\(String(format: "%.5f", coordinate.latitude))|\(String(format: "%.5f", coordinate.longitude))"
        self.name = resolvedName
        self.address = Self.addressText(from: mark)
        self.coordinate = coordinate
        self.category = mapItem.pointOfInterestCategory
        self.phoneNumber = mapItem.phoneNumber
        self.websiteURL = mapItem.url
        self.mapItem = mapItem
        self.isDroppedPin = false
    }

    /// Builds a place without an existing `MKMapItem` — used for dropped pins and saved places.
    init(
        name: String,
        address: String,
        coordinate: CLLocationCoordinate2D,
        category: MKPointOfInterestCategory? = nil,
        phoneNumber: String? = nil,
        websiteURL: URL? = nil,
        isDroppedPin: Bool = false
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? (isDroppedPin ? "Dropped pin" : "Unnamed place") : trimmedName
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedAddress = trimmedAddress.isEmpty ? Formatters.coordinate(coordinate) : trimmedAddress

        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = resolvedName
        item.phoneNumber = phoneNumber
        item.url = websiteURL
        item.pointOfInterestCategory = category

        self.id = isDroppedPin
            ? Self.droppedPinID(for: coordinate)
            : "\(resolvedName)|\(String(format: "%.5f", coordinate.latitude))|\(String(format: "%.5f", coordinate.longitude))"
        self.name = resolvedName
        self.address = resolvedAddress
        self.coordinate = coordinate
        self.category = category
        self.phoneNumber = phoneNumber
        self.websiteURL = websiteURL
        self.mapItem = item
        self.isDroppedPin = isDroppedPin
    }

    static func droppedPinID(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "pin|%.6f|%.6f", coordinate.latitude, coordinate.longitude)
    }

    static func addressText(from mark: CLPlacemark, fallback: String = "Address unavailable") -> String {
        var parts: [String] = []

        if let number = mark.subThoroughfare, let street = mark.thoroughfare {
            parts.append("\(number) \(street)")
        } else if let street = mark.thoroughfare {
            parts.append(street)
        } else if let name = mark.name, !name.isEmpty {
            parts.append(name)
        }

        if let locality = mark.locality, !locality.isEmpty {
            parts.append(locality)
        }
        if let area = mark.administrativeArea, !area.isEmpty, area != (mark.locality ?? "") {
            parts.append(area)
        }

        return parts.isEmpty ? fallback : parts.joined(separator: ", ")
    }

    var coordinateText: String {
        Formatters.coordinate(coordinate)
    }

    var categoryName: String {
        if isDroppedPin { return "Dropped pin" }
        return category?.mapLabel ?? "Place"
    }

    var symbolName: String {
        if isDroppedPin { return "mappin" }
        return category?.symbolName ?? "mappin.and.ellipse"
    }

    var tint: Color {
        if isDroppedPin { return AppTheme.red }
        return category?.tint ?? AppTheme.blue
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
