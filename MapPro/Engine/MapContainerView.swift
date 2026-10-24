import SwiftUI
import MapKit
import UIKit

struct MapContainerView: UIViewRepresentable {
    @ObservedObject var engine: MapEngine

    func makeCoordinator() -> Coordinator {
        Coordinator(engine: engine)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.mapType = engine.mapLayer.mapType
        mapView.showsUserLocation = true
        mapView.showsBuildings = true
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsTraffic = engine.trafficEnabled
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        mapView.pointOfInterestFilter = .includingAll
        mapView.setRegion(engine.mapRegion, animated: false)

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMapPan(_:))
        )
        pan.cancelsTouchesInView = false
        pan.delegate = context.coordinator
        mapView.addGestureRecognizer(pan)

        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMapLongPress(_:))
        )
        longPress.minimumPressDuration = 0.45
        longPress.allowableMovement = 8
        longPress.cancelsTouchesInView = false
        longPress.delegate = context.coordinator
        mapView.addGestureRecognizer(longPress)

        context.coordinator.mapView = mapView
        context.coordinator.lastIs3D = engine.is3D
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.engine = engine

        if mapView.mapType != engine.mapLayer.mapType {
            mapView.mapType = engine.mapLayer.mapType
        }
        if mapView.showsTraffic != engine.trafficEnabled {
            mapView.showsTraffic = engine.trafficEnabled
        }

        if coordinator.lastIs3D != engine.is3D {
            coordinator.lastIs3D = engine.is3D
            var camera = mapView.camera
            camera.pitch = engine.is3D ? 58 : 0
            mapView.setCamera(camera, animated: true)
        }

        syncAnnotations(mapView)
        syncSelection(mapView)
        syncRoute(mapView, coordinator: coordinator)

        if let command = engine.cameraCommand, coordinator.lastCameraCommandID != command.id {
            coordinator.lastCameraCommandID = command.id
            coordinator.apply(command, on: mapView)
        }
    }

    private func syncAnnotations(_ mapView: MKMapView) {
        let pins = engine.mapPins
        let current = mapView.annotations.compactMap { $0 as? PlaceAnnotation }
        let currentIDs = Set(current.map { $0.place.id })
        let desiredIDs = Set(pins.map { $0.id })
        guard currentIDs != desiredIDs else { return }

        mapView.removeAnnotations(current)
        let annotations = pins.map { PlaceAnnotation(place: $0) }
        mapView.addAnnotations(annotations)
    }

    private func syncSelection(_ mapView: MKMapView) {
        let annotations = mapView.annotations.compactMap { $0 as? PlaceAnnotation }

        for annotation in annotations {
            let chosen = annotation.place.id == engine.selectedPlace?.id
            if let annotationView = mapView.view(for: annotation) as? PlaceAnnotationView {
                annotationView.setChosen(chosen, animated: true)
            }
        }

        if let selected = engine.selectedPlace,
           let annotation = annotations.first(where: { $0.place.id == selected.id }) {
            let isAlreadySelected = mapView.selectedAnnotations.contains {
                ($0 as? PlaceAnnotation)?.place.id == selected.id
            }
            if !isAlreadySelected {
                mapView.selectAnnotation(annotation, animated: true)
            }
        } else {
            for selectedAnnotation in mapView.selectedAnnotations {
                mapView.deselectAnnotation(selectedAnnotation, animated: true)
            }
        }
    }

    private func syncRoute(_ mapView: MKMapView, coordinator: Coordinator) {
        let routeID = engine.selectedRoute?.id
        guard coordinator.displayedRouteID != routeID else { return }

        if !coordinator.routeOverlays.isEmpty {
            mapView.removeOverlays(coordinator.routeOverlays)
            coordinator.routeOverlays.removeAll()
        }

        coordinator.displayedRouteID = routeID

        guard let selectedRoute = engine.selectedRoute else { return }

        let polyline = selectedRoute.polyline
        mapView.addOverlay(polyline)
        coordinator.routeOverlays = [polyline]
        mapView.setVisibleMapRect(
            polyline.boundingMapRect,
            edgePadding: UIEdgeInsets(top: 120, left: 48, bottom: 400, right: 48),
            animated: true
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var engine: MapEngine
        weak var mapView: MKMapView?
        var lastCameraCommandID: UUID?
        var lastIs3D: Bool
        var displayedRouteID: UUID?
        var routeOverlays: [MKOverlay] = []

        init(engine: MapEngine) {
            self.engine = engine
            self.lastIs3D = engine.is3D
            super.init()
        }

        func apply(_ command: CameraCommand, on mapView: MKMapView) {
            switch command.target {
            case .coordinate(let coordinate, let altitude):
                let camera = MKMapCamera(
                    lookingAtCenter: coordinate,
                    fromDistance: altitude,
                    pitch: engine.is3D ? 58 : 0,
                    heading: 0
                )
                mapView.setCamera(camera, animated: true)

            case .region(let region):
                mapView.setRegion(region, animated: true)

            case .rect(let rect, let padding):
                mapView.setVisibleMapRect(rect, edgePadding: padding, animated: true)

            case .navigation(let coordinate, let heading):
                let camera = MKMapCamera(
                    lookingAtCenter: coordinate,
                    fromDistance: 720,
                    pitch: 52,
                    heading: heading
                )
                mapView.setCamera(camera, animated: true)

            case .resetNorth:
                var camera = mapView.camera
                camera.heading = 0
                camera.pitch = engine.is3D ? 58 : 0
                mapView.setCamera(camera, animated: true)
            }
        }

        @objc func handleMapPan(_ gesture: UIPanGestureRecognizer) {
            guard gesture.state == .ended || gesture.state == .cancelled else { return }
            if !engine.places.isEmpty {
                engine.showSearchArea = true
            }
        }

        @objc func handleMapLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began, let mapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            engine.dropPin(at: coordinate)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard gestureRecognizer is UILongPressGestureRecognizer, let mapView else { return true }

            var hitView = mapView.hitTest(touch.location(in: mapView), with: nil)
            while let current = hitView {
                if let placeView = current as? PlaceAnnotationView,
                   let annotation = placeView.annotation as? PlaceAnnotation,
                   annotation.place.isDroppedPin {
                    return false
                }
                hitView = current.superview
            }
            return true
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let placeAnnotation = annotation as? PlaceAnnotation else { return nil }

            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: PlaceAnnotationView.reuseIdentifier
            ) as? PlaceAnnotationView
                ?? PlaceAnnotationView(
                    annotation: placeAnnotation,
                    reuseIdentifier: PlaceAnnotationView.reuseIdentifier
                )

            view.annotation = placeAnnotation
            view.isDraggable = placeAnnotation.place.isDroppedPin
            view.setChosen(placeAnnotation.place.id == engine.selectedPlace?.id, animated: false)
            return view
        }

        func mapView(
            _ mapView: MKMapView,
            annotationView view: MKAnnotationView,
            didChange newState: MKAnnotationView.DragState,
            fromOldState oldState: MKAnnotationView.DragState
        ) {
            guard let annotation = view.annotation as? PlaceAnnotation,
                  annotation.place.isDroppedPin else { return }

            switch newState {
            case .ending:
                engine.moveDroppedPin(to: annotation.coordinate)
            case .canceling:
                annotation.coordinate = annotation.place.coordinate
            default:
                break
            }
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation as? PlaceAnnotation else { return }
            engine.select(place: annotation.place)
        }

        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            guard let annotation = view.annotation as? PlaceAnnotation else { return }
            if engine.selectedPlace?.id == annotation.place.id {
                engine.clearSelection()
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let region = mapView.region
            let old = engine.mapRegion

            let moved = abs(region.center.latitude - old.center.latitude) > 0.00001
                || abs(region.center.longitude - old.center.longitude) > 0.00001
                || abs(region.span.latitudeDelta - old.span.latitudeDelta) > 0.00001
                || abs(region.span.longitudeDelta - old.span.longitudeDelta) > 0.00001

            if moved {
                engine.updateVisibleRegion(region)
            }
            engine.updateHeading(mapView.camera.heading)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor(AppTheme.blue)
            renderer.lineWidth = 7
            renderer.lineCap = .round
            renderer.lineJoin = .round
            renderer.alpha = 0.95
            return renderer
        }
    }
}
