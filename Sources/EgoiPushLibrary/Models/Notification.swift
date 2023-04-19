//
//  Notification.swift
//  
//
//  Created by João Silva on 29/10/2022.
//

public struct Notification {
    public var notification: NotificationObject = NotificationObject()
    public var data: DataObject = DataObject()
    
    public struct NotificationObject {
        public var title: String = ""
        public var body: String = ""
        public var image: String = ""
    }
    
    public struct DataObject {
        public var os: String = "ios"
        public var messageHash: String = ""
        public var listID: Int = 0
        public var contactID: String = ""
        public var accountID: Int = 0
        public var applicationID: String = ""
        public var messageID: Int = 0
        public var deviceID: Int = 0
        public var geo: Geo = Geo()
        public var actions: Action = Action()
        
        public struct Geo {
            public var latitude: Double = 0
            public var longitude: Double = 0
            public var radius: Double = 0
            public var duration: Int = 0
            public var periodStart: String? = nil
            public var periodEnd: String? = nil
        }
        
        public struct Action: Codable {
            public var type: String = ""
            public var text: String = ""
            public var url: String = ""
            public var textCancel: String = ""
            
            private enum CodingKeys: String, CodingKey {
                case type
                case text
                case url
                case textCancel = "text-cancel"
            }
        }
    }
}
