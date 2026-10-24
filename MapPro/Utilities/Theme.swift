import SwiftUI
import MapKit
import UIKit

enum AppTheme {
    static let blue = Color(red: 0.10, green: 0.45, blue: 0.91)
    static let green = Color(red: 0.20, green: 0.66, blue: 0.33)
    static let red = Color(red: 0.92, green: 0.26, blue: 0.21)
    static let yellow = Color(red: 0.98, green: 0.74, blue: 0.02)
    static let orange = Color(red: 0.96, green: 0.52, blue: 0.16)
    static let purple = Color(red: 0.55, green: 0.36, blue: 0.86)
    static let teal = Color(red: 0.10, green: 0.62, blue: 0.62)

    static let cardCorner: CGFloat = 26
}

extension MKPointOfInterestCategory {
    /// A short human readable label for the category.
    var mapLabel: String {
        if self == .restaurant { return "Restaurant" }
        if self == .cafe { return "Coffee shop" }
        if self == .bakery { return "Bakery" }
        if self == .brewery { return "Brewery" }
        if self == .winery { return "Winery" }
        if self == .nightlife { return "Nightlife" }
        if self == .gasStation { return "Gas station" }
        if self == .evCharger { return "EV charging" }
        if self == .parking { return "Parking" }
        if self == .hotel { return "Hotel" }
        if self == .foodMarket { return "Supermarket" }
        if self == .pharmacy { return "Pharmacy" }
        if self == .hospital { return "Hospital" }
        if self == .park { return "Park" }
        if self == .nationalPark { return "National park" }
        if self == .beach { return "Beach" }
        if self == .marina { return "Marina" }
        if self == .campground { return "Campground" }
        if self == .zoo { return "Zoo" }
        if self == .museum { return "Museum" }
        if self == .movieTheater { return "Movie theater" }
        if self == .theater { return "Theater" }
        if self == .stadium { return "Stadium" }
        if self == .amusementPark { return "Amusement park" }
        if self == .aquarium { return "Aquarium" }
        if self == .library { return "Library" }
        if self == .store { return "Store" }
        if self == .bank { return "Bank" }
        if self == .atm { return "ATM" }
        if self == .airport { return "Airport" }
        if self == .publicTransport { return "Transit stop" }
        if self == .school { return "School" }
        if self == .university { return "University" }
        if self == .fitnessCenter { return "Gym" }
        if self == .postOffice { return "Post office" }
        if self == .police { return "Police" }
        if self == .fireStation { return "Fire station" }
        return "Place"
    }

    /// SF Symbol shown on pins and rows.
    var symbolName: String {
        if self == .restaurant { return "fork.knife" }
        if self == .cafe { return "cup.and.saucer.fill" }
        if self == .bakery { return "birthday.cake.fill" }
        if self == .brewery { return "mug.fill" }
        if self == .winery { return "wineglass.fill" }
        if self == .nightlife { return "wineglass.fill" }
        if self == .gasStation { return "fuelpump.fill" }
        if self == .evCharger { return "bolt.car.fill" }
        if self == .parking { return "parkingsign.circle.fill" }
        if self == .hotel { return "bed.double.fill" }
        if self == .foodMarket { return "cart.fill" }
        if self == .pharmacy { return "cross.case.fill" }
        if self == .hospital { return "cross.case.fill" }
        if self == .park { return "leaf.fill" }
        if self == .nationalPark { return "mountain.2.fill" }
        if self == .beach { return "sun.max.fill" }
        if self == .marina { return "sailboat.fill" }
        if self == .campground { return "tent.fill" }
        if self == .zoo { return "pawprint.fill" }
        if self == .museum { return "building.columns.fill" }
        if self == .movieTheater { return "film.fill" }
        if self == .theater { return "theatermasks.fill" }
        if self == .stadium { return "sportscourt.fill" }
        if self == .amusementPark { return "sparkles" }
        if self == .aquarium { return "fish.fill" }
        if self == .library { return "books.vertical.fill" }
        if self == .store { return "bag.fill" }
        if self == .bank { return "building.columns.fill" }
        if self == .atm { return "creditcard.fill" }
        if self == .airport { return "airplane" }
        if self == .publicTransport { return "tram.fill" }
        if self == .school { return "graduationcap.fill" }
        if self == .university { return "graduationcap.fill" }
        if self == .fitnessCenter { return "figure.run" }
        if self == .postOffice { return "envelope.fill" }
        if self == .police { return "shield.fill" }
        if self == .fireStation { return "flame.fill" }
        return "mappin.and.ellipse"
    }

    var tint: Color {
        if self == .restaurant || self == .cafe || self == .bakery || self == .brewery || self == .winery || self == .nightlife {
            return AppTheme.orange
        }
        if self == .gasStation || self == .evCharger || self == .parking || self == .airport || self == .publicTransport || self == .bank || self == .atm {
            return AppTheme.blue
        }
        if self == .hotel || self == .museum || self == .movieTheater || self == .theater || self == .library || self == .stadium || self == .amusementPark || self == .aquarium {
            return AppTheme.purple
        }
        if self == .pharmacy || self == .hospital || self == .fireStation || self == .police {
            return AppTheme.red
        }
        if self == .park || self == .nationalPark || self == .beach || self == .marina || self == .campground || self == .zoo || self == .foodMarket {
            return AppTheme.green
        }
        if self == .school || self == .university || self == .store {
            return AppTheme.yellow
        }
        return AppTheme.blue
    }
}

extension Color {
    static let mapCanvas = Color(uiColor: .secondarySystemBackground)
}
