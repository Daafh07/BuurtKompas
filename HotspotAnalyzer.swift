//
//  HotspotAnalyzer.swift
//
//  Bronvermelding (APA 7):
//  Google. (2025). *Clustering Concepts* [Tech notes].
//  Apple Inc. (2025). *Core Location – Coordinates* [Developer documentation].
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI.
//

import Foundation
import CoreLocation

struct Hotspot: Identifiable {
    let id = UUID()
    let center: CLLocationCoordinate2D
    let count: Int
    let categoryTop: String?
}

/// Eenvoudige raster-clustering: groepeer punten in “cellen” van ca. 500–700m.
/// - Parameter cellSizeDeg: grootte van gridcel in graden; 0.005 ≈ ~550m breed (lat).
/// - Retourneert top-N hotspots gesorteerd op aantal meldingen.
func buildHotspots(
    from reports: [Report],
    cellSizeDeg: Double = 0.005,
    topN: Int = 5
) -> [Hotspot] {
    // Bucket key: (latKey, lonKey)
    struct BucketKey: Hashable { let lat: Int; let lon: Int }
    var buckets: [BucketKey: (count: Int, cats: [String: Int])] = [:]

    for r in reports {
        guard let coord = r.coordinate else { continue }
        let latKey = Int((coord.latitude / cellSizeDeg).rounded())
        let lonKey = Int((coord.longitude / cellSizeDeg).rounded())
        let key = BucketKey(lat: latKey, lon: lonKey)

        var entry = buckets[key] ?? (0, [:])
        entry.count += 1
        entry.cats[r.category, default: 0] += 1
        buckets[key] = entry
    }

    // Bouw Hotspot objecten
    var result: [Hotspot] = []
    result.reserveCapacity(buckets.count)

    for (key, entry) in buckets {
        // Zet key terug om naar center-coordinate van de cel
        let centerLat = Double(key.lat) * cellSizeDeg
        let centerLon = Double(key.lon) * cellSizeDeg

        // Populairste categorie binnen de cel
        let topCat = entry.cats.max(by: { $0.value < $1.value })?.key
        result.append(
            Hotspot(center: .init(latitude: centerLat, longitude: centerLon),
                    count: entry.count,
                    categoryTop: topCat)
        )
    }

    // Sorteer op count desc en pak topN
    return result.sorted(by: { $0.count > $1.count }).prefix(topN).map { $0 }
}
