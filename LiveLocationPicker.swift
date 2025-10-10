//
//  LiveLocationPicker.swift
//
//  Bronvermelding (APA 7):
//  Apple Inc. (2025). *MapKit & User Location* [Developer documentation]. Apple Developer.
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI.
//
//  Kaart met live user-locatie + verplaatsbare pin.
//

import SwiftUI
import MapKit
import CoreLocation

struct LiveLocationPicker: UIViewRepresentable {
    @Binding var latitude: Double?
    @Binding var longitude: Double?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.userTrackingMode = .follow
        map.pointOfInterestFilter = .excludingAll
        map.isPitchEnabled = false
        map.showsCompass = false

        // Vraag permissie & start updates via de coordinator (houdt manager vast)
        context.coordinator.requestAuthAndStart()

        // Tik om pin te plaatsen/verplaatsen
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        map.addGestureRecognizer(tap)

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Niets nodig; bindings leven in de coordinator.
        // (We gaan hier NIET proberen @Binding toe te wijzen aan Double.)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(latitude: $latitude, longitude: $longitude)
    }

    // MARK: - Coordinator
    final class Coordinator: NSObject, MKMapViewDelegate, CLLocationManagerDelegate {
        @Binding var latitude: Double?
        @Binding var longitude: Double?

        // CLLocationManager MOET sterk worden vastgehouden
        private let manager = CLLocationManager()
        private weak var mapView: MKMapView?

        private var pin: MKPointAnnotation?

        init(latitude: Binding<Double?>, longitude: Binding<Double?>) {
            self._latitude = latitude
            self._longitude = longitude
            super.init()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        }

        func requestAuthAndStart() {
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                manager.startUpdatingLocation()
            default:
                break
            }
        }

        // Bewaar een verwijzing naar de map zodra beschikbaar
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            self.mapView = mapView
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: map)
            let coord = map.convert(point, toCoordinateFrom: map)
            placePin(on: map, at: coord)
        }

        private func placePin(on map: MKMapView, at coord: CLLocationCoordinate2D) {
            if let pin {
                pin.coordinate = coord
            } else {
                let ann = MKPointAnnotation()
                ann.coordinate = coord
                map.addAnnotation(ann)
                pin = ann
            }
            latitude = coord.latitude
            longitude = coord.longitude
        }

        // MARK: - CLLocationManagerDelegate
        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.startUpdatingLocation()
            default:
                break
            }
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let map = mapView ?? (manager.delegate as? Coordinator)?.mapView ?? nil else { return }
            guard let loc = locations.last else { return }

            // Als gebruiker nog geen locatie koos → zet pin op user-locatie
            if latitude == nil || longitude == nil {
                placePin(on: map, at: loc.coordinate)
                map.setCenter(loc.coordinate, animated: true)
            }
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            print("Location error:", error)
        }

        // MARK: - MKMapViewDelegate
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            let id = "user-pin"
            let v = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            v.annotation = annotation
            v.isDraggable = true
            v.canShowCallout = false
            v.markerTintColor = .systemBlue
            v.glyphImage = UIImage(systemName: "mappin.circle.fill")
            return v
        }

        func mapView(_ mapView: MKMapView,
                     annotationView view: MKAnnotationView,
                     didChange newState: MKAnnotationView.DragState,
                     fromOldState oldState: MKAnnotationView.DragState) {
            guard let ann = view.annotation, newState == .ending else { return }
            latitude = ann.coordinate.latitude
            longitude = ann.coordinate.longitude
        }
    }
}
