//
//  NotificationHandler.swift
//  
//
//  Created by João Silva on 29/10/2022.
//

import SwiftUI
import Foundation
import UserNotifications

public struct NotificationHandler {
    private static let userNotificationCenter: UNUserNotificationCenter = UNUserNotificationCenter.current()
    static var pendingNotifications: [String: Notification] = [:]
    
    // MARK: Public level functions
    
    /// Creates a temporary notification category with the actions defined on your E-goi campaign and adds it to the notification that's going to be presented.
    /// When the notification is opened or dismissed, the category is deleted from the application.
    public static func processNotificationContent(
        _ bestAttemptContent: UNMutableNotificationContent,
        callback: @escaping (_ b: UNMutableNotificationContent) -> Void
    ) {
        guard let aps = bestAttemptContent.userInfo["aps"] as? NSDictionary else {
            callback(bestAttemptContent)
            return
        }
        
        guard let messageHash = aps["message-hash"] as? String else {
            callback(bestAttemptContent)
            return
        }
        
        guard let actionsJson = aps["actions"] as? String, actionsJson != "" else {
            callback(bestAttemptContent)
            return
        }
        
        let actionsData = actionsJson.data(using: .utf8)!
        
        do {
            let actions: Notification.DataObject.Action = try JSONDecoder().decode(Notification.DataObject.Action.self, from: actionsData)
            
            guard !actions.type.isEmpty, !actions.text.isEmpty, !actions.url.isEmpty, !actions.textCancel.isEmpty else {
                callback(bestAttemptContent)
                return
            }
            
            let confirmAction = UNNotificationAction(identifier: "confirm", title: actions.text, options: UNNotificationActionOptions.foreground)
            let cancelAction = UNNotificationAction(identifier: "close", title: actions.textCancel, options: UNNotificationActionOptions.destructive)
            
            let category = UNNotificationCategory(identifier: messageHash, actions: [confirmAction, cancelAction], intentIdentifiers: [], options: UNNotificationCategoryOptions.customDismissAction)
            
            bestAttemptContent.categoryIdentifier = messageHash
            
            UNUserNotificationCenter.current().getNotificationCategories() { cats in
                UNUserNotificationCenter.current().setNotificationCategories(cats.union([category]))
                // This sleep is required to give time for the category to be register in the application before displaying the notification
                usleep(500000)
                callback(bestAttemptContent)
            }
        } catch {
            print(error)
            print("Invalid actions json.")
            callback(bestAttemptContent)
            return
        }
    }
    
    /// Build a notification and add it to the pending notifications.
    public static func processNotification(_ userInfo: [AnyHashable : Any], callback: (UIBackgroundFetchResult) -> Void) {
        guard let notification = buildNotification(userInfo) else {
            callback(.failed)
            return
        }
        
        if notification.data.geo.latitude != 0,
           notification.data.geo.longitude != 0,
           notification.data.geo.radius != 0
        {
            LocationHandler.addRegion(
                latitude: notification.data.geo.latitude,
                longitude: notification.data.geo.longitude,
                radius: notification.data.geo.radius,
                duration: notification.data.geo.duration,
                identifier: notification.data.messageHash
            )
        }
        
        callback(.noData)
    }
    
    /// Handle interactions with a notification
    /// - Parameters:
    ///   - response: The interaction with the notification
    ///   - completionHandler: The callback of the function
    public static func handleNotificationInteraction(
        _ response: UNNotificationResponse,
        _ completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        guard let key = userInfo["key"] as? String,
              let notification = NotificationHandler.pendingNotifications[key]
        else {
            print("Notification not found.")
            completionHandler()
            return
        }
        
        NotificationHandler.pendingNotifications.removeValue(forKey: key)
        
        Network().registerEvent(
            event: .RECEIVED,
            notification: notification
        ) { result in
            print("Event \"\(EventType.RECEIVED.rawValue)\" registered: \(result)")
        }
        
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            if notification.data.actions.text != "",
               notification.data.actions.type != "",
               notification.data.actions.url != "",
               notification.data.actions.textCancel != ""
            {
                
            } else {
                Network().registerEvent(
                    event: .OPEN,
                    notification: notification
                ) { result in
                    print("Event \"\(EventType.OPEN.rawValue)\" registered: \(result)")
                }
            }
            break
            
        case "confirm":
            Network().registerEvent(
                event: .OPEN,
                notification: notification
            ) { result in
                print("Event \"\(EventType.OPEN.rawValue)\" registered: \(result)")
            }
            
            switch notification.data.actions.type {
            case "deeplink":
                break
                
            case "http":
                if notification.data.actions.url != "", let url = URL(string: notification.data.actions.url) {
                    DispatchQueue.main.async {
                        if UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                break
                
            default:
                print("Invalid URL type.")
                break
            }
            break
            
        case "close":
            Network().registerEvent(
                event: .CLOSE,
                notification: notification
            ) { result in
                print("Event \"\(EventType.CLOSE.rawValue)\" registered: \(result)")
            }
            break
            
        default:
            break
        }
        
        NotificationHandler.userNotificationCenter.getNotificationCategories { categories in
            var cats = categories as Set<UNNotificationCategory>
            cats = cats.filter { $0.identifier != "temp_cat" && $0.identifier != notification.data.messageHash }
            NotificationHandler.userNotificationCenter.setNotificationCategories(cats)
            
            DispatchQueue.main.async {
                completionHandler()
            }
        }
    }
    
    // MARK: Package level functions
    
    /// Present a pending notification as a local notification in the device.
    /// - Parameters:
    ///   - identifier: The identifier of the pending notification that will be presented.
    static func sendNotification(identifier: String) {
        guard let notification = NotificationHandler.pendingNotifications[identifier] else {
            print("Could not find the notification.")
            return
        }
        
        guard let request = createRequest(notification) else {
            print("Failed to create the notification request.")
            return
        }
        
        NotificationHandler.userNotificationCenter.add(request) { error in
            if error != nil {
                print(error ?? "Unkown error.")
                return
            }
        }
    }
    
    // MARK: Private level functions
    
    /// Build a message with the notification data and add it to the pending notifications map
    /// - Parameters:
    ///   - userInfo: The notification data
    /// - Returns: Returns a message
    private static func buildNotification(_ userInfo: [AnyHashable: Any]) -> Notification? {
        guard let aps = userInfo["aps"] as? NSDictionary else {
            return nil
        }
        
        guard let messageHash = aps["message-hash"] as? String else {
            return nil
        }
        
        var notification: Notification = Notification()
        
        notification.notification.title = aps["title"] as? String ?? ""
        notification.notification.body = aps["body"] as? String ?? ""
        notification.notification.image = aps["image"] as? String ?? ""
        
        notification.data.messageHash = messageHash
        notification.data.listID = Int(aps["list-id"] as! String) ?? 0
        notification.data.contactID = aps["contact-id"] as? String ?? ""
        notification.data.accountID = Int(aps["account-id"] as! String) ?? 0
        notification.data.applicationID = aps["application-id"] as? String ?? ""
        notification.data.messageID = Int(aps["message-id"] as! String) ?? 0
        notification.data.geo.latitude = Double(aps["latitude"] as! String) ?? 0
        notification.data.geo.longitude = Double(aps["longitude"] as! String) ?? 0
        notification.data.geo.radius = Double(aps["radius"] as! String) ?? 0
        notification.data.geo.duration = Int(aps["duration"] as! String) ?? 0
        notification.data.geo.periodStart = aps["time-start"] as? String ?? nil
        notification.data.geo.periodEnd = aps["time-end"] as? String ?? nil
        
        if let actionsJson = aps["actions"] as? String, let actions = actionsJson.data(using: .utf8) {
            do {
                notification.data.actions = try JSONDecoder().decode(Notification.DataObject.Action.self, from: actions)
            } catch {}
        }
        
        pendingNotifications[messageHash] = notification
        
        return notification
    }
    
    /// Create a notification request
    /// - Parameter message: The message to use to create the requests
    /// - Returns: The request
    private static func createRequest(_ notification: Notification) -> UNNotificationRequest? {
        let content = UNMutableNotificationContent()
        
        content.title = notification.notification.title
        content.body = notification.notification.body
        content.sound = UNNotificationSound.default
        content.badge = (UIApplication.shared.applicationIconBadgeNumber + 1) as NSNumber
        
        content.userInfo = ["key": notification.data.messageHash]
        
        if notification.notification.image != "", let url = URL(string: notification.notification.image) {
            let group = DispatchGroup()
            group.enter()
            
            DispatchQueue.global(qos: .default).async {
                guard let data = try? Data(contentsOf: url) else {
                    return
                }
                
                guard let attachment = saveImage("image.png", data: data, options: nil) else {
                    return
                }

                content.attachments = [attachment]
                group.leave()
            }
            
            group.wait()
        }
        
        if notification.data.actions.text != "", notification.data.actions.textCancel != "" {
            let confirmAction = UNNotificationAction(identifier: "confirm", title: notification.data.actions.text, options: [UNNotificationActionOptions.foreground])
            let cancelAction = UNNotificationAction(identifier: "close", title: notification.data.actions.textCancel, options: [UNNotificationActionOptions.destructive])
            
            let category = UNNotificationCategory(identifier: notification.data.messageHash, actions: [confirmAction, cancelAction], intentIdentifiers: [], options: UNNotificationCategoryOptions.customDismissAction)
            
            NotificationHandler.userNotificationCenter.getNotificationCategories() { cats in
                NotificationHandler.userNotificationCenter.setNotificationCategories(cats.union([category]))
            }
            
            content.categoryIdentifier = notification.data.messageHash
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        return UNNotificationRequest(identifier: notification.data.messageHash, content: content, trigger: trigger)
    }
    
    /// Save an image to a temporary directory to show on the notification
    /// - Parameters:
    ///   - identifier: The name with which the file will be saved
    ///   - data: The image data
    ///   - options: UNNotificationAttachment options
    /// - Returns: UNNotificationAttachment
    private static func saveImage(_ identifier: String, data: Data, options: [AnyHashable: Any]?) -> UNNotificationAttachment? {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            let fileURL = directory.appendingPathComponent(identifier)
            try data.write(to: fileURL, options: [])
            
            return try UNNotificationAttachment(identifier: identifier, url: fileURL, options: options)
        } catch {}
        
        return nil
    }
    
    private static func presentDialog(notification: Notification) {
        let alert = UIAlertController(
            title: notification.notification.title,
            message: notification.notification.body,
            preferredStyle: .alert
        )
        
        if notification.data.actions.type != "",
           notification.data.actions.text != "",
           notification.data.actions.url != "",
           notification.data.actions.textCancel != ""
        {
            let close = UIAlertAction(title: notification.data.actions.textCancel, style: .destructive) { _ in
                Network().registerEvent(
                    event: .CLOSE,
                    notification: notification
                ) { result in
                    print("Event \"\(EventType.CLOSE.rawValue)\" registered: \(result)")
                }
            }
            
            alert.addAction(close)
            
            let confirm = UIAlertAction(title: notification.data.actions.text, style: .default) { _ in
                Network().registerEvent(
                    event: .OPEN,
                    notification: notification
                ) { result in
                    print("Event \"\(EventType.OPEN.rawValue)\" registered: \(result)")
                }
                
                if (notification.data.actions.type == "deeplink") {
                    
                } else {
                    if let url = URL(string: notification.data.actions.url) {
                        DispatchQueue.main.async {
                            if UIApplication.shared.canOpenURL(url) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }
            }
            
            alert.addAction(confirm)
        }
        
        
    }
}
