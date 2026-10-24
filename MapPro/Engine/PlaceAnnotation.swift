import MapKit
import UIKit

final class PlaceAnnotation: NSObject, MKAnnotation {
    let place: Place
    var coordinate: CLLocationCoordinate2D

    var title: String? { place.name }
    var subtitle: String? { place.address }

    init(place: Place) {
        self.place = place
        self.coordinate = place.coordinate
        super.init()
    }
}
