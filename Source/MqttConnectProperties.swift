//
//  MqttConnectProperties.swift
//  CocoaMQTT
//
//  Created by liwei wang on 2021/7/25.
//

import Foundation

public class MqttConnectProperties: NSObject {
    // 3.1.2.11.1 Property Length
    // public var propertyLength: UInt8?
    // 3.1.2.11.2 Session Expiry Interval
    public var sessionExpiryInterval: UInt32?
    // 3.1.2.11.3 Receive Maximum
    public var receiveMaximum: UInt16?
    // 3.1.2.11.4 Maximum Packet Size
    public var maximumPacketSize: UInt32?
    // 3.1.2.11.5 Topic Alias Maximum
    public var topicAliasMaximum: UInt16?
    // 3.1.2.11.6 Request Response Information
    public var requestResponseInformation: UInt8?
    // 3.1.2.11.7 Request Problem Information
    public var requestProblemInfomation: UInt8?
    // 3.1.2.11.8 User Property
    public var userProperties: [String: String]?
    // 3.1.2.11.9 Authentication Method
    public var authenticationMethod: String?
    // 3.1.2.11.10 Authentication Data
    public var authenticationData: [UInt8]?

    public var properties: [UInt8] {
        var properties = [UInt8]()

        // 3.1.2.11.2 Session Expiry Interval
        if let sessionExpiryInterval = self.sessionExpiryInterval {
            properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.sessionExpiryInterval.rawValue, value: sessionExpiryInterval.byteArrayLittleEndian)
        }

        // 3.1.2.11.3 Receive Maximum
        if let receiveMaximum = self.receiveMaximum {
            properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.receiveMaximum.rawValue, value: receiveMaximum.hlBytes)
        }

        // 3.1.2.11.4 Maximum Packet Size
        if let maximumPacketSize = self.maximumPacketSize {
            properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.maximumPacketSize.rawValue, value: maximumPacketSize.byteArrayLittleEndian)
        }

        // 3.1.2.11.5 Topic Alias Maximum
        if let topicAliasMaximum = self.topicAliasMaximum {
            properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.topicAliasMaximum.rawValue, value: topicAliasMaximum.hlBytes)
        }

        // 3.1.2.11.6 Request Response Information
        if let requestResponseInformation = self.requestResponseInformation {
            properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.requestResponseInformation.rawValue, value: [requestResponseInformation])
        }
        // 3.1.2.11.7 Request Problem Information
        if let requestProblemInfomation = self.requestProblemInfomation {
            properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.requestProblemInformation.rawValue, value: [requestProblemInfomation])
        }
        // 3.1.2.11.8 User Property
        if let userProperty = self.userProperties {
            for (key, value) in userProperty {
                properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.userProperty.rawValue, value: key.bytesWithLength + value.bytesWithLength)
            }
        }
        // 3.1.2.11.9 Authentication Method
        if let authenticationMethod = self.authenticationMethod {
            properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.authenticationMethod.rawValue, value: authenticationMethod.bytesWithLength)
        }
        // 3.1.2.11.10 Authentication Data
        if let authenticationData = self.authenticationData {
            properties += authenticationData
        }

        return properties
    }
}
