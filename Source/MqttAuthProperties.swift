//
//  MqttAuthProperties.swift
//  CocoaMQTT
//
//  Created by liwei wang on 1/9/2021.
//

import Foundation

public class MqttAuthProperties: NSObject {
    // 3.15.2.2.2 Authentication Method
    public var authenticationMethod: String?
    // 3.15.2.2.3 Authentication Data
    public var authenticationData: [UInt8]?
    // 3.15.2.2.4 Reason String
    public var reasonString: String?
    // 3.15.2.2.5 User Property
    public var userProperties: [String: String]?

    public var properties: [UInt8] {
        var properties = [UInt8]()

        // 3.15.2.2.2 Authentication Method
        if let authenticationMethod = self.authenticationMethod {
            properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.authenticationMethod.rawValue, value: authenticationMethod.bytesWithLength)
        }
        // 3.15.2.2.3 Authentication Data
        if let authenticationData = self.authenticationData {
            properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.authenticationData.rawValue, value: authenticationData)
        }
        // 3.15.2.2.4 Reason String
        if let reasonString = self.reasonString {
            properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.reasonString.rawValue, value: reasonString.bytesWithLength)
        }
        // 3.15.2.2.5 User Property
        if let userProperty = self.userProperties {
            for (key, value) in userProperty {
                properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.userProperty.rawValue, value: key.bytesWithLength + value.bytesWithLength)
            }
        }

        return properties
    }
}
