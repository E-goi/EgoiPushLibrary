import Foundation

public struct EgoiPushLibrary {
    private let userDefaults = UserDefaults.standard
    
    public init(appId: String, apiKey: String) {
        guard appId != "" else {
            print("Missing E-goi's application ID.")
            return
        }
        
        guard apiKey != "" else {
            print("Missing E-goi's API key.")
            return
        }
        
        userDefaults.set(appId, forKey: UserDefaultsProperties.APP_ID)
        userDefaults.set(apiKey, forKey: UserDefaultsProperties.API_KEY)
    }
}
