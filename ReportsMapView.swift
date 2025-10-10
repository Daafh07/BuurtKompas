//
//  ReportsMapView.swift
//
//  Bronvermelding (APA 7):
//  Apple Inc. (2025). *MapKit (MKMapView & clustering)* [Developer documentation]. Apple Developer.
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI. https://chat.openai.com/
//  --
//  Toont meldingen als pins; roept onSelect(report) aan bij tik op pin.
//

import SwiftUI
import MapKit

// MARK: Annotation wrapper
final class ReportAnnotation: NSObject, MKAnnotation {
    let report: Report
    let coordinate: CLLocationCoordinate2D
    init?(_ report: Report) {
        guard let c = report.coordinate else { return nil }
        self.report = report
        self.coordinate = c
    }
    var title: String? { report.title }
    var subtitle: String? { report.categoryLabel }
}

// MARK: Representable
struct ReportsMapView: UIViewRepresentable {
    let annotations: [ReportAnnotation]
    var onSelect: ((Report) -> Void)? = nil   // <— nieuw

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "pin")
        map.pointOfInterestFilter = .excludingAll
        map.showsUserLocation = true
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.onSelect = onSelect // sync closure
        map.removeAnnotations(map.annotations)
        map.addAnnotations(annotations)

        if map.region.span.latitudeDelta == 0 || map.annotations.count == 1 {
            let region = MKCoordinateRegion(
                center: annotations.first?.coordinate ?? .init(latitude: 52.1, longitude: 5.1),
                span: .init(latitudeDelta: 0.4, longitudeDelta: 0.4)
            )
            map.setRegion(region, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onSelect: ((Report) -> Void)?
        init(onSelect: ((Report) -> Void)?) { self.onSelect = onSelect }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let ann = annotation as? ReportAnnotation else { return nil }
            let v = mapView.dequeueReusableAnnotationView(withIdentifier: "pin", for: ann) as! MKMarkerAnnotationView
            v.canShowCallout = false   // we gebruiken eigen sheet
            v.clusteringIdentifier = "report"
            v.markerTintColor = ann.report.categoryUIColor
            v.glyphImage = UIImage(systemName: ann.report.categorySymbol)
            return v
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            // Negeer cluster taps; die gebruiken de standaard zoom
            if view.annotation is MKClusterAnnotation { return }
            guard
                let ann = view.annotation as? ReportAnnotation,
                let onSelect
            else { return }
            onSelect(ann.report)
            mapView.deselectAnnotation(view.annotation, animated: false)
        }
    }
}
