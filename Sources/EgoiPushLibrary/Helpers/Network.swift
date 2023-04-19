//
//  Network.swift
//  
//
//  Created by João Silva on 10/01/2023.
//

import SwiftUI

private enum HttpTarget: String {
    case TOKEN = "token"
    case EVENT = "event"
}

public enum EventType: String {
    case OPEN = "open"
    case CLOSE = "canceled"
    case RECEIVED = "received"
}

public struct Network {
    private let userDefaults = UserDefaults.standard
    private let host = "https://api.egoiapp.com"
    
    private let apiKey: String
    private let appID: String
    
    public init() {
        self.apiKey = userDefaults.string(forKey: UserDefaultsProperties.API_KEY) ?? ""
        self.appID = userDefaults.string(forKey: UserDefaultsProperties.APP_ID) ?? ""
    }
    
    public func registerToken(field: String, callback: @escaping ((_ result: Bool) -> Void)) {
        guard let token = userDefaults.string(forKey: UserDefaultsProperties.TOKEN),
              let value = userDefaults.string(forKey: UserDefaultsProperties.TOKEN_IDENTIFIER),
              var request = getRequest(target: .TOKEN)
        else {
            callback(false)
            return
        }
        
        var payload: Data
        
        do {
            payload = try JSONSerialization.data(
                withJSONObject: [
                    "token": token,
                    "os": "ios",
                    "two_steps_data": [
                        "field": field,
                        "value": value
                    ]
                ] as [String : Any],
                options: .prettyPrinted
            )
        } catch {
            callback(false)
            return
        }
        
        request.httpBody = payload
        
        runRequest(request) { result in
            callback(result)
        }
    }
    
    public func registerEvent(
        event: EventType,
        notification: Notification,
        callback: @escaping ((_ result: Bool) -> Void)
    ) {
        guard var request = getRequest(target: .EVENT) else {
            callback(false)
            return
        }
        
        var payload: Data
        
        do {
            payload = try JSONSerialization.data(
                withJSONObject: [
                    "os": "ios",
                    "event": event.rawValue,
                    "contact": notification.data.contactID,
                    "message_hash": notification.data.messageHash
                ]
            )
        } catch {
            callback(false)
            return
        }
        
        request.httpBody = payload
        
        runRequest(request) { result in
            callback(result)
        }
    }
    
    private func getRequest(target: HttpTarget) -> URLRequest? {
        guard let url = URL(string: "\(host)/push/apps/\(appID)/\(target.rawValue)") else {
            return nil
        }
        
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
        )
        
        request.httpMethod = "POST"
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "ApiKey")
        
        return request
    }
    
    private func runRequest(_ request: URLRequest, callback: @escaping ((_ result: Bool) -> Void)) {
        let dataTask = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Request error: \(error)")
                callback(false)
                return
            }
            
            guard let response = response as? HTTPURLResponse else {
                callback(false)
                return
            }
            
            guard response.statusCode == 202 else {
                callback(false)
                return
            }
            
            callback(true)
        }
        
        dataTask.resume()
    }
}
