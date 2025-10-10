//
//  DensityCircle.swift
//
//  Additive “bubble” overlay: één cirkel per melding.
//  Overlap = feller door .plusLighter (additive compositing).
//  Inclusief zachte glow voor hoge dichtheid.
//

import Foundation
import MapKit
import UIKit

// MARK: - Model
public struct HeatmapPoint {
    public let coordinate: CLLocationCoordinate2D
    public let weight: CGFloat
    public init(_ coordinate: CLLocationCoordinate2D, weight: CGFloat = 1) {
        self.coordinate = coordinate
        self.weight = max(0, weight)
    }
}

// MARK: - Overlay
public final class DensityCircleOverlay: NSObject, MKOverlay {
    public let coordinate: CLLocationCoordinate2D
    public let radiusMeters: CLLocationDistance
    public let color: UIColor
    public let alpha: CGFloat
    public let boundingMapRect: MKMapRect

    public init(center: CLLocationCoordinate2D,
                radiusMeters: CLLocationDistance,
                color: UIColor,
                alpha: CGFloat) {
        self.coordinate = center
        self.radiusMeters = max(5, radiusMeters)
        self.color = color
        self.alpha = max(0.0, min(1.0, alpha))

        let mp = MKMapPoint(center)
        let metersPerPoint = MKMetersPerMapPointAtLatitude(center.latitude)
        let rp = radiusMeters / metersPerPoint
        self.boundingMapRect = MKMapRect(x: mp.x - rp, y: mp.y - rp, width: rp * 2, height: rp * 2)
        super.init()
    }
}

// MARK: - Renderer
public final class DensityCircleRenderer: MKOverlayRenderer {

    private let minPixelRadius: CGFloat = 24

    public override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in ctx: CGContext) {
        guard let o = overlay as? DensityCircleOverlay else { return }
        if !mapRect.intersects(o.boundingMapRect) { return }

        let centerPoint = point(for: MKMapPoint(o.coordinate))
        let metersPerPoint = MKMetersPerMapPointAtLatitude(o.coordinate.latitude)
        let radiusPoints = o.radiusMeters / metersPerPoint
        let radiusPx = max(minPixelRadius, CGFloat(radiusPoints) * zoomScale)
        let rect = CGRect(x: centerPoint.x - radiusPx, y: centerPoint.y - radiusPx,
                          width: radiusPx * 2, height: radiusPx * 2)

        ctx.saveGState()
        ctx.setBlendMode(.plusLighter)

        // Haal kleurcomponenten
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        o.color.getRed(&r, green: &g, blue: &b, alpha: &a)

        // 🔥 Subtiele glow toevoegen: groter, transparanter
        let glowAlpha = o.alpha * 0.25
        let glowRect = rect.insetBy(dx: -radiusPx * 0.5, dy: -radiusPx * 0.5)
        ctx.setFillColor(o.color.withAlphaComponent(glowAlpha).cgColor)
        ctx.fillEllipse(in: glowRect)

        // Kern: radiale gradient (kleur → transparant)
        guard let cs = CGColorSpace(name: CGColorSpace.sRGB) else { ctx.restoreGState(); return }
        let comps: [CGFloat] = [ r,g,b,o.alpha,  r,g,b,0.0 ]
        let locs: [CGFloat] = [ 0.0, 1.0 ]

        if let grad = CGGradient(colorSpace: cs, colorComponents: comps, locations: locs, count: 2) {
            ctx.addEllipse(in: rect)
            ctx.clip()
            let c = CGPoint(x: rect.midX, y: rect.midY)
            ctx.drawRadialGradient(grad, startCenter: c, startRadius: 0,
                                   endCenter: c, endRadius: radiusPx,
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        } else {
            ctx.setFillColor(o.color.withAlphaComponent(o.alpha).cgColor)
            ctx.fillEllipse(in: rect)
        }

        ctx.restoreGState()

        // Zachte rand-outline
        ctx.saveGState()
        ctx.setLineWidth(max(1, 2 / zoomScale))
        ctx.setStrokeColor(o.color.withAlphaComponent(0.15).cgColor)
        ctx.strokeEllipse(in: rect)
        ctx.restoreGState()
    }
}
