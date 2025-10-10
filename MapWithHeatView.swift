//
//  MapWithHeatView.swift
//
//  Bronvermelding (APA 7):
//  Apple Inc. (2025). *MapKit – MKMapViewDelegate & Overlays* [Developer documentation].
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI.
//
//  MKMapView met pins + dynamische heat/density-overlay.
//

import SwiftUI
import MapKit
import CoreLocation

final class ReportAnnotationPoint: MKPointAnnotation {
    let reportId: String
    let category: String
    init(reportId: String, coordinate: CLLocationCoordinate2D, category: String) {
        self.reportId = reportId
        self.category = category
        super.init()
        self.coordinate = coordinate
    }
}

struct MapWithHeatView: UIViewRepresentable {

    struct Item {
        let reportId: String
        let coordinate: CLLocationCoordinate2D
        let weight: Int
        let category: String
    }

    let items: [Item]
    let showHeat: Bool
    let baseRadiusMeters: CLLocationDistance
    let neighborhoodMeters: CLLocationDistance
    let initialRegion: MKCoordinateRegion?
    let onSelect: (String) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.isRotateEnabled = false
        map.pointOfInterestFilter = .includingAll
        if let initialRegion { map.setRegion(initialRegion, animated: false) }
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeAnnotations(map.annotations)
        let pins = items.map {
            ReportAnnotationPoint(reportId: $0.reportId, coordinate: $0.coordinate, category: $0.category)
        }
        map.addAnnotations(pins)

        map.removeOverlays(map.overlays)
        guard showHeat, !items.isEmpty else { return }

        let zoomScale = map.visibleMapRect.size.width / map.bounds.size.width
        let dynamicRadius = baseRadiusMeters * (zoomScale / 4000.0).clamped(to: 0.4...2.8)

        // Dichtheid
        var tValues = Array(repeating: CGFloat(0), count: items.count)
        var maxNeighbors = 1
        for i in 0..<items.count {
            var neighbors = 1
            let ci = items[i].coordinate
            let locI = CLLocation(latitude: ci.latitude, longitude: ci.longitude)
            for j in 0..<items.count where j != i {
                let cj = items[j].coordinate
                let d = locI.distance(from: CLLocation(latitude: cj.latitude, longitude: cj.longitude))
                if d <= neighborhoodMeters { neighbors += 1 }
            }
            maxNeighbors = max(maxNeighbors, neighbors)
            tValues[i] = CGFloat(neighbors)
        }
        if maxNeighbors > 1 {
            for k in 0..<tValues.count { tValues[k] /= CGFloat(maxNeighbors) }
        } else {
            for k in 0..<tValues.count { tValues[k] = 0.1 }
        }

        var overlays: [DensityCircleOverlay] = []
        for (idx, it) in items.enumerated() {
            let likeBoost = min(1.0, log10(Float(max(1, it.weight))) / 1.3)
            let t = min(1.0, max(0.0, 0.10 + tValues[idx] * 0.85 + CGFloat(likeBoost) * 0.20))
            let color = heatColor(for: t)
            let alpha = heatAlpha(for: t, minA: 0.22, maxA: 0.95)
            overlays.append(DensityCircleOverlay(center: it.coordinate,
                                                 radiusMeters: dynamicRadius,
                                                 color: color,
                                                 alpha: alpha))
        }

        map.addOverlays(overlays, level: .aboveRoads)
    }

    func makeCoordinator() -> Coord { Coord(onSelect: onSelect) }

    final class Coord: NSObject, MKMapViewDelegate {
        let onSelect: (String) -> Void
        init(onSelect: @escaping (String) -> Void) { self.onSelect = onSelect }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            guard let point = annotation as? ReportAnnotationPoint else { return nil }

            let id = "reportPin"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
                view?.canShowCallout = false
                view?.displayPriority = .required
            } else {
                view?.annotation = annotation
            }

            switch point.category.lowercased() {
            case "verlichting":
                view?.glyphImage = UIImage(systemName: "lightbulb.fill")
                view?.markerTintColor = .systemYellow
            case "vuilnisbak":
                view?.glyphImage = UIImage(systemName: "trash.fill")
                view?.markerTintColor = .systemGreen
            case "verkeer":
                view?.glyphImage = UIImage(systemName: "car.fill")
                view?.markerTintColor = .systemBlue
            case "vandalisme":
                view?.glyphImage = UIImage(systemName: "hammer.fill")
                view?.markerTintColor = .systemRed
            case "overlast":
                view?.glyphImage = UIImage(systemName: "exclamationmark.triangle.fill")
                view?.markerTintColor = .systemOrange
            default:
                view?.glyphImage = UIImage(systemName: "questionmark.circle.fill")
                view?.markerTintColor = .systemGray
            }

            view?.glyphTintColor = .white
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let point = view.annotation as? ReportAnnotationPoint else { return }
            onSelect(point.reportId)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if overlay is DensityCircleOverlay {
                return DensityCircleRenderer(overlay: overlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Helpers
private func heatAlpha(for t: CGFloat, minA: CGFloat, maxA: CGFloat) -> CGFloat {
    minA + (maxA - minA) * min(1, max(0, t))
}

private func heatColor(for t: CGFloat) -> UIColor {
    let clamped = min(1, max(0, t))
    switch clamped {
    case ..<0.25:
        let k = clamped / 0.25
        return UIColor(red: 0.00, green: 0.22 + 0.43*k, blue: 0.60 + 0.14*k, alpha: 1.0)
    case ..<0.50:
        let k = (clamped - 0.25) / 0.25
        return UIColor(red: 0.00 + 0.40*k, green: 0.65 + 0.20*k, blue: 0.74 - 0.34*k, alpha: 1.0)
    case ..<0.75:
        let k = (clamped - 0.50) / 0.25
        return UIColor(red: 0.40 + 0.58*k, green: 0.85 + 0.02*k, blue: 0.40 - 0.20*k, alpha: 1.0)
    default:
        let k = (clamped - 0.75) / 0.25
        return UIColor(red: 0.98 - 0.03*k, green: 0.87 - 0.52*k, blue: 0.20 + 0.05*k, alpha: 1.0)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(range.upperBound, max(range.lowerBound, self))
    }
}
