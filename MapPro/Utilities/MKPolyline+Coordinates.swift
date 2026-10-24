import MapKit

extension MKPolyline {
    /// First coordinate in the polyline, used to center the camera and to track step progress.
    var firstCoordinate: CLLocationCoordinate2D? {
        guard pointCount > 0 else { return nil }
        var coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        getCoordinates(&coordinate, range: NSRange(location: 0, length: 1))
        return coordinate
    }
}
