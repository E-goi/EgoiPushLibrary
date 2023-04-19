//
//  File.swift
//  
//
//  Created by João Silva on 12/04/2023.
//

import CoreLocation

class LocationDelegate: NSObject, CLLocationManagerDelegate {
    private static let locationManager = CLLocationManager()
    private static var regionsMonitored: [String: CLCircularRegion] = [:]
    private static var runningTimers: [String: Timer] = [:]
    
    override init() {
        super.init()
        LocationDelegate.locationManager.delegate = self
    }
    
    /// Request permission to access the location of the device when the app is in foreground.
    func requestLocationAccess() {
        LocationDelegate.locationManager.requestWhenInUseAuthorization()
    }
    
    /// Request permission to access the location of the device when the app is background.
    func requestLocationAccessInBackground() {
        LocationDelegate.locationManager.requestAlwaysAuthorization()
    }
    
    /// Create a region for testing purposes.
    func addTestRegion() {
        monitorRegion(
            region: createRegionAtCoordinates(latitude: 41.178880, longitude: -8.682427, radius: 100, identifier: "TEST"),
            duration: (2 * 60 * 1000) / 1000
        )
    }
    
    /// Start monitoring a region.
    /// - Parameters:
    ///   - region: The region to be monitored.
    ///   - duration: The duration of the region. (optional)
    func monitorRegion(region: CLCircularRegion, duration: Int? = nil) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            print("Monitoring not available.")
            return
        }
        
        if insideRegion(region) {
            NotificationHandler.sendNotification(identifier: region.identifier)
        } else {
            LocationDelegate.locationManager.startUpdatingLocation()
            LocationDelegate.locationManager.startMonitoring(for: region)
            LocationDelegate.regionsMonitored[region.identifier] = region
            
            if let duration = duration, duration > 0 {
                startTimer(duration, region)
            }
            
            print("Geofence \(region.identifier) created.")
        }
    }
    
    /// Create a region based on the specified coordinates.
    /// - Parameters:
    ///   - latitude: The latitude of the region's center.
    ///   - longitude: The longitude of the region's center.
    ///   - radius: The radius of the region.
    ///   - identifier: The identifier of the region.
    /// - Returns:A region with the center at the given coordinates.
    func createRegionAtCoordinates(latitude: Double, longitude: Double, radius: Double, identifier: String) -> CLCircularRegion {
        let center = CLLocationCoordinate2D(latitude: CLLocationDegrees(latitude), longitude: CLLocationDegrees(longitude))
        let region = CLCircularRegion(center: center, radius: CLLocationDistance(radius), identifier: identifier)
        
        region.notifyOnEntry = true
        region.notifyOnExit = false
        
        return region
    }
    
    @available(iOS 14.0, *)
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .notDetermined:
            break
            
        case .authorizedAlways:
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
            break
            
        case .restricted, .denied:
            manager.stopUpdatingLocation()
            manager.allowsBackgroundLocationUpdates = false
            manager.showsBackgroundLocationIndicator = false
            break
            
        @unknown default:
            manager.stopUpdatingLocation()
            manager.allowsBackgroundLocationUpdates = false
            manager.showsBackgroundLocationIndicator = false
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if #unavailable(iOS 14.0) {
            switch status {
            case .authorizedWhenInUse, .notDetermined:
                break
                
            case .authorizedAlways:
                manager.allowsBackgroundLocationUpdates = true
                manager.showsBackgroundLocationIndicator = true
                break
                
            case .restricted, .denied:
                manager.stopUpdatingLocation()
                manager.allowsBackgroundLocationUpdates = false
                manager.showsBackgroundLocationIndicator = false
                break
                
            @unknown default:
                manager.stopUpdatingLocation()
                manager.allowsBackgroundLocationUpdates = false
                manager.showsBackgroundLocationIndicator = false
            }
        }
    }
    
    /// Handle the "Enter" trigger of a monitored region.
    /// - Parameters:
    ///   - manager: The instance of the CLLocationManager that is monitoring the region.
    ///   - region: The region that got triggered.
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let region = region as? CLCircularRegion else {
            print("Unkown region triggered.")
            return
        }
        
        guard let notification = NotificationHandler.pendingNotifications[region.identifier] else {
            print("Notification not found for current region.")
            return
        }
        
        if let periodStart = notification.data.geo.periodStart,
           let periodEnd = notification.data.geo.periodEnd,
           periodStart != "",
           periodEnd != ""
        {
            let periodStartSplit = periodStart.split(separator: ":")
            let periodEndSplit = periodEnd.split(separator: ":")

            let date = Date()

            guard let startHour = Int(periodStartSplit[0]),
                  let startMinute = Int(periodStartSplit[1]),
                  let startDate = Calendar.current.date(bySettingHour: startHour, minute: startMinute, second: 0, of: date),
                  let endHour = Int(periodEndSplit[0]),
                  let endMinute = Int(periodEndSplit[1]),
                  let endDate = Calendar.current.date(bySettingHour: endHour, minute: endMinute, second: 0, of: date),
                  date >= startDate,
                  date <= endDate
            else {
                print("Outside defined period.")
                return
            }
        }
        
        stopMonitoringRegion(region)
        
        NotificationHandler.sendNotification(identifier: region.identifier)
    }
    
    /// Start a timer for the specified region.
    /// - Parameters:
    ///   - duration: The duration of the timer in seconds.
    ///   - region: The region that will be associated with the timer.
    private func startTimer(_ duration: Int, _ region: CLCircularRegion) {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .second, value: duration, to: Date())
        
        guard let date = date else {
            print("Invalid date format.")
            return
        }
        
        let timer = Timer(fireAt: date, interval: 0, target: self, selector: #selector(stopMonitoringRegionFromTimer), userInfo: region, repeats: false)
        RunLoop.current.add(timer, forMode: .common)
        LocationDelegate.runningTimers[region.identifier] = timer
    }
    
    /// Stop a timer with the specified identifier.
    /// - Parameters:
    ///   - identifier: The identifier of the timer to be stopped.
    private func stopTimer(identifier: String) {
        guard let timer = LocationDelegate.runningTimers[identifier] else {
            print("Timer with identifier \(identifier) not found.")
            return
        }
        
        timer.invalidate()
        LocationDelegate.runningTimers.removeValue(forKey: identifier)
        print("Timer with identifier \(identifier) removed.")
    }
    
    /// Stop monitoring a region when the associated timer ends.
    /// - Parameters:
    ///    - timer: The timer that ended.
    @objc
    private func stopMonitoringRegionFromTimer(timer: Timer) {
        guard let region = timer.userInfo as? CLCircularRegion else {
            print("Invalid region.")
            return
        }
        
        stopMonitoringRegion(region)
    }
    
    /// Stop monitoring the specified region.
    /// - Parameters:
    ///   - region: The region to stop monitoring.
    private func stopMonitoringRegion(_ region: CLCircularRegion) {
        LocationDelegate.locationManager.stopMonitoring(for: region)
        LocationDelegate.regionsMonitored.removeValue(forKey: region.identifier)
        
        if LocationDelegate.regionsMonitored.isEmpty {
            LocationDelegate.locationManager.stopUpdatingLocation()
        }
        
        print("Geofence \(region.identifier) removed.")
        
        stopTimer(identifier: region.identifier)
    }
    
    /// Validate if the user is inside of the the region created during the geofence created.
    /// - Parameters:
    ///   - region: The target region.
    /// - Returns: True or False
    private func insideRegion(_ region: CLCircularRegion) -> Bool {
        guard let location = LocationDelegate.locationManager.location?.coordinate else {
            return false
        }
        
        let currentLocation: CLLocation = CLLocation(latitude: CLLocationDegrees(location.latitude), longitude: CLLocationDegrees(location.longitude))
        let targetLocation: CLLocation = CLLocation(latitude: CLLocationDegrees(region.center.latitude), longitude: CLLocationDegrees(region.center.longitude))
        let distance = currentLocation.distance(from: targetLocation)
        
        return distance.isLessThanOrEqualTo(region.radius)
    }
}
