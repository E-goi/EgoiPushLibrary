//
//  File.swift
//  
//
//  Created by João Silva on 12/04/2023.
//

import Foundation

public struct LocationHandler {
    private static let delegate: LocationDelegate = LocationDelegate()
    
    public static func requestLocationAccess() {
        LocationHandler.delegate.requestLocationAccess()
    }
    
    public static func requestLocationAccessInBackground() {
        LocationHandler.delegate.requestLocationAccessInBackground()
    }
    
    public static func addTestRegion() {
        var notification = Notification()
        notification.notification.title = "Geofence triggered!"
        notification.notification.body = "Geofence TEST was triggered."
        notification.notification.image = "https://media.licdn.com/dms/image/D4D0BAQG6xPl2tobmnQ/company-logo_200_200/0/1666870374567?e=2147483647&v=beta&t=TmR6lpk4262l4uEhh7uymckCcSsjF2sTZ5nB6ZRmlgs"
        
        notification.data.os = "ios"
        notification.data.contactID = "590b169771"
        notification.data.messageHash = "TEST"
        notification.data.applicationID = "egoipushlibrary"
        notification.data.actions.type = "http"
        notification.data.actions.text = "View"
        notification.data.actions.url = "https://www.e-goi.com"
        notification.data.actions.textCancel = "Close"
        
        NotificationHandler.pendingNotifications["TEST"] = notification
        LocationHandler.delegate.addTestRegion()
    }
    
    static func addRegion(latitude: Double, longitude: Double, radius: Double, duration: Int, identifier: String) {
        LocationHandler.delegate.monitorRegion(
            region: LocationHandler.delegate.createRegionAtCoordinates(
                latitude: latitude,
                longitude: longitude,
                radius: radius,
                identifier: identifier
            ),
            duration: duration / 1000
        )
    }
}
