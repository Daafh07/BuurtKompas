//
//  LocationManager.swift
//
//  Bronvermelding (APA 7):
//  Apple Inc. (2025). *Core Location* [Developer documentation]. Apple Developer.
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI.
//

import CoreLocation

final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    private let manager = CLLocationManager()
    private(set) var lastLocation: CLLocation?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestWhenInUse() {
        // iOS 14+: gebruik instance property
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    func requestOneLocation() {
        let status = manager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // hier zou je de gebruiker naar Instellingen kunnen sturen
            break
        @unknown default:
            break
        }
    }

    // MARK: - Delegate

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // Zodra we toestemming hebben, vraag meteen 1 locatie op
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error)
    }
}
