//
//  MqttPublishProperties.swift
//  CocoaMQTT
//
//  Created by liwei wang on 2021/7/27.
//

import Foundation

public class MqttPublishProperties: NSObject {


    //3.3.2.3 PUBLISH Properties
    //3.3.2.3.1 Property Length
    public var propertyLength: Int?
    //3.3.2.3.2 Payload Format Indicator
    public var payloadFormatIndicator: PayloadFormatIndicator?
    //3.3.2.3.3 Message Expiry Interval
    public var messageExpiryInterval: UInt32?
    //3.3.2.3.4 Topic Alias
    public var topicAlias: UInt16?
    //3.3.2.3.5 Response Topic
    public var responseTopic: String?
    //3.3.2.3.6 Correlation Data
    public var correlationData: [UInt8]?
    //3.3.2.3.7 Property
    public var userProperty: [String: String]?
    //3.3.2.3.8 Subscription Identifier
    public var subscriptionIdentifier: UInt32?
    //3.3.2.3.9 Content Type
    public var contentType: String?

    public init(
        propertyLength: Int? = nil,
        payloadFormatIndicator: PayloadFormatIndicator? = nil,
        messageExpiryInterval: UInt32? = nil,
        topicAlias: UInt16? = nil,
        responseTopic: String? = nil,
        correlation: String? = nil,
        userProperty: [String: String]? = nil,
        subscriptionIdentifier: UInt32? = nil,
        contentType: String? = nil
    ) {
        self.propertyLength = propertyLength
        self.payloadFormatIndicator = payloadFormatIndicator
        self.messageExpiryInterval = messageExpiryInterval
        self.topicAlias = topicAlias
        self.responseTopic = responseTopic
        self.correlationData = correlation?.bytesWithLength
        self.userProperty = userProperty
        self.subscriptionIdentifier = subscriptionIdentifier
        self.contentType = contentType
    }

    public var properties: [UInt8] {
        var properties = [UInt8]()

        //3.3.2.3.2  Payload Format Indicator
        if let payloadFormatIndicator = self.payloadFormatIndicator {
            properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.payloadFormatIndicator.rawValue, value: [payloadFormatIndicator.rawValue])
        }
        //3.3.2.3.3  Message Expiry Interval
        if let messageExpiryInterval = self.messageExpiryInterval {
            properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.willExpiryInterval.rawValue, value: messageExpiryInterval.byteArrayLittleEndian)
        }
        //3.3.2.3.4 Topic Alias
        if let topicAlias = self.topicAlias {
            properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.topicAlias.rawValue, value: topicAlias.hlBytes)
        }
        //3.3.2.3.5 Response Topic
        if let responseTopic = self.responseTopic {
            properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.responseTopic.rawValue, value: responseTopic.bytesWithLength)
        }
        //3.3.2.3.6 Correlation Data
        if let correlationData = self.correlationData {
            properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.correlationData.rawValue, value: correlationData)
        }
        //3.3.2.3.7 Property Length User Property
        if let userProperty = self.userProperty {
            properties += userProperty.userPropertyBytes
        }
        //3.3.2.3.8 Subscription Identifier
        if let subscriptionIdentifier = self.subscriptionIdentifier,
           let subscriptionIdentifier = beVariableByteInteger(subscriptionIdentifier) {
            properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.subscriptionIdentifier.rawValue, value: subscriptionIdentifier)
        }
        //3.3.2.3.9 Content Type
        if let contentType = self.contentType {
            properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.contentType.rawValue, value: contentType.bytesWithLength)
        }


        

        return properties
    }
}
