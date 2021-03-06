//
//  EgoiPushLibrary.swift
//  EgoiPushLibrary
//
//  Created by João Silva on 15/01/2021.
//
import UIKit

public final class EgoiPushLibrary {
    private var backgroundTaskID: UIBackgroundTaskIdentifier?
    private var locationHandler: LocationHandler?
    private var notificationHandler : NotificationHandler?
    private var field: String?
    private var value: String?
    
    private var tokenRegistered: Bool = false
    
    public static let shared = EgoiPushLibrary()
    
    var appId: String?
    var apiKey: String?
    
    var geoEnabled: Bool = true
    var dialogCallBack: ((EGoiMessage) -> Void)?
    var deepLinkCallBack: ((EGoiMessage) -> Void)?
    
    /// Initiate the E-goi's library
    /// - Parameters:
    ///   - appId: The ID of the E-goi's app
    ///   - apiKey: The API Key of the E-goi's account
    ///   - geoEnabled: Enable the geolocation functionality
    ///   - deepLinkCallBack: Callback to be invoked when the action type of the notification is a deeplink
    public func config(
        appId: String,
        apiKey: String,
        geoEnabled: Bool = true,
        dialogCallBack: ((EGoiMessage) -> Void)? = nil,
        deepLinkCallBack: ((EGoiMessage) -> Void)? = nil
    ) {
        self.appId = appId
        self.apiKey = apiKey
        self.geoEnabled = geoEnabled
        self.dialogCallBack = dialogCallBack
        self.deepLinkCallBack = deepLinkCallBack
        
        // Initialize Handlers
        notificationHandler = NotificationHandler()
        
        if geoEnabled {
            locationHandler = LocationHandler()
        }
    }
    
    /// Add the Firebase token to the library. If the user is already registered in E-goi's list and the token is diferent from the registered one, update the token.
    /// - Parameter token: The token generated by Firebase
    public func addFCMToken(token: String) {
        if token != notificationHandler?.token {
            notificationHandler?.token = token
            
            if tokenRegistered {
                guard let field = self.field, let value = self.value else {
                    print("Failed to update the token")
                    return
                }
                
                sendToken(field: field, value: value) { success, message in
                    if !success {
                        guard let string = message else {
                            print("Failed to update the token")
                            return
                        }
                        
                        print("Failed to update the token", string)
                    }
                }
            }
        }
    }
    
    // MARK: - Location
    
    /// Request permission to access the location when the app is in foreground
    public func requestForegroundLocationAccess() {
        if self.geoEnabled {
            locationHandler?.requestForegroundAccess()
        }
    }
    
    /// Request permission to access the location when the app is in background
    public func requestBackgroundLocationAccess() {
        if self.geoEnabled {
            locationHandler?.requestBackgroundAccess()
        }
    }
    
    /// Create a geofence that will trigger a notification
    /// - Parameter message: The data of the notification to be triggered
    func createGeofence(message: EGoiMessage) {
        if self.geoEnabled {
            locationHandler?.createGeofence(message: message)
        }
    }
    
    /// Check if the monitoring of geofences is available
    /// - Returns: True or False
    func isMonitoringAvailable() -> Bool {
        guard let handler = locationHandler else {
            return false
        }
        
        return handler.isMonitoringAvailable()
    }
    
    // MARK: - Notification
    
    /// Process the remote notification received
    /// - Parameters:
    ///   - userInfo: The data of the remote notification
    ///   - callback: The callback to call after processing the notification
    func processNotification(
        _ userInfo: [AnyHashable : Any],
        callback: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        notificationHandler?.processNotification(userInfo: userInfo)
        callback(.noData)
    }
    
    /// Send a local notification to the user
    /// - Parameter key: The key that identifies the notification on the pending notifications map
    func fireNotification(key: String) {
        notificationHandler?.fireNotification(key: key)
    }
    
    func deletePendingNotification(key: String) {
        notificationHandler?.deletePendingNotification(key: key)
    }
    
    // MARK: - Requests
    
    /// Send an user's interaction with the notification to E-goi
    /// - Parameters:
    ///   - event: The interaction of the user
    ///   - message: The notification the user interacted with
    func sendEvent(_ event: String, message: EGoiMessage) {
        guard let apiKey = self.apiKey,
              let appId = self.appId,
              let contactId = message.data.contactId,
              let messageHash = message.data.messageHash
        else {
            return
        }
        
        // Send the event to E-goi in a background thread
        DispatchQueue.global().async {
            self.backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "Send Event") {
                UIApplication.shared.endBackgroundTask(self.backgroundTaskID!)
                self.backgroundTaskID = UIBackgroundTaskIdentifier.invalid
            }
            
            PushNetworking.sendEvent(
                appId: appId,
                apiKey: apiKey,
                contactID: contactId,
                messageHash: messageHash,
                deviceId: message.data.deviceId,
                event: event
            ) { success in
                print("Sent event: \(event) to server. Result: \(success)")
                
                UIApplication.shared.endBackgroundTask(self.backgroundTaskID!)
                self.backgroundTaskID = UIBackgroundTaskIdentifier.invalid
            }
        }
    }
    
    /// Register the Firebase token in E-goi's contact list
    /// - Parameters:
    ///   - field: The field to identify the registration with
    ///   - value: The value related to the field
    ///   - callback: The response of the registration
    public func sendToken(field: String?, value: String?, callback: @escaping (_ success: Bool, _ message: String?) -> Void) {
        if field != nil, field != self.field {
            self.field = field
        }
        
        if value != nil, value != self.value {
            self.value = value
        }
        
        guard let wrappedToken = notificationHandler?.token else {
            callback(false, "Não existe token para enviar")
            return
        }
        
        guard let wrappedApiKey = self.apiKey, let wrappedAppId = self.appId else {
            callback(false, "Falta configuração de conta!")
            return
        }
        
        PushNetworking.sendToken(
            appId: wrappedAppId,
            apiKey: wrappedApiKey,
            field: self.field,
            value: self.value,
            token: wrappedToken
        ) { (success) in
            if success {
                self.tokenRegistered = true
            }
            
            callback(success, success ? nil : "Erro ao registar o token")
        }
    }
}
