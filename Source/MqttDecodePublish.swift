//
//  MqttDecodePublish.swift
//  CocoaMQTT
//
//  Created by liwei wang on 2021/7/27.
//

import Foundation

public class MqttDecodePublish: NSObject {
    // 3.3.2.3 PUBLISH Properties
    // 3.3.2.3.1 Property Length
    public var propertyLength: Int?
    // 3.3.2.3.2 Payload Format Indicator
    public var payloadFormatIndicator: PayloadFormatIndicator?
    // 3.3.2.3.3 Message Expiry Interval
    public var messageExpiryInterval: UInt32?
    // 3.3.2.3.4 Topic Alias
    public var topicAlias: UInt16?
    // 3.3.2.3.5 Response Topic
    public var responseTopic: String?
    // 3.3.2.3.6 Correlation Data
    public var correlationData: [UInt8]?
    // 3.3.2.3.7 Property
    public var userProperty: [String: String]?
    // 3.3.2.3.8 Subscription Identifier
    public var subscriptionIdentifier: Int = 0
    // 3.3.2.3.9 Content Type
    public var contentType: String?

    // public var applicationMessage: [UInt8]?

    // 3.3.2.1 Topic Name
    public var topic: String = ""
    // 3.3.2.2 Packet Identifier
    public var packetIdentifier: UInt16?

    public func decodePublish(fixedHeader: UInt8, publishData: [UInt8]) {
        // Topic Name
        // 3.3.2.1 Topic Name
        var dataIndex = 0
        guard let result = unsignedByteToString(data: publishData, offset: dataIndex) else {
            return
        }
        self.topic = result.resStr
        dataIndex = result.newOffset

        printDebug("topic = \(topic)")

        guard let recQos = CocoaMQTTQoS(rawValue: (fixedHeader & 0b0000_0110) >> 1) else {
            return
        }

        // 3.3.2.2 Packet Identifier
        // Packet Identifier
        if recQos == .qos1 || recQos == .qos2 {
            let identifierResult = integerCompute(data: publishData, formatType: FormatInt.formatUint16.rawValue, offset: dataIndex)
            packetIdentifier = UInt16(identifierResult!.res)
            dataIndex = identifierResult!.newOffset
        }

        var protocolVersion = ""
        if let storage = CocoaMQTTStorage() {
            protocolVersion = storage.queryMQTTVersion()
        }

        if protocolVersion == "5.0" {
            // 3.3.2.3.1 Property Length
            // propertyLength
            let propertyLengthVariableByteInteger = decodeVariableByteInteger(data: publishData, offset: dataIndex)
            propertyLength = propertyLengthVariableByteInteger.res
            dataIndex = propertyLengthVariableByteInteger.newOffset

            let occupyIndex = dataIndex

            while dataIndex < occupyIndex + (propertyLength ?? 0) {
                let resVariableByteInteger = decodeVariableByteInteger(data: publishData, offset: dataIndex)
                dataIndex = resVariableByteInteger.newOffset
                let propertyNameByte = resVariableByteInteger.res
                guard let propertyName = CocoaMQTTPropertyName(rawValue: UInt8(propertyNameByte)) else {
                    break
                }
                switch propertyName.rawValue {
                // 3.3.2.3.2 Payload Format Indicator
                case CocoaMQTTPropertyName.payloadFormatIndicator.rawValue:
                    if publishData[dataIndex] & 0b0000_0001 > 0 {
                        payloadFormatIndicator = .utf8
                    } else {
                        payloadFormatIndicator = .unspecified
                    }
                    dataIndex += 1

                // 3.3.2.3.3 Message Expiry Interval
                case CocoaMQTTPropertyName.willExpiryInterval.rawValue:
                    let comRes = integerCompute(data: publishData, formatType: FormatInt.formatUint32.rawValue, offset: dataIndex)
                    messageExpiryInterval = UInt32(comRes!.res)
                    dataIndex = comRes!.newOffset

                // 3.3.2.3.4 Topic Alias
                case CocoaMQTTPropertyName.topicAlias.rawValue:
                    let comRes = integerCompute(data: publishData, formatType: FormatInt.formatUint16.rawValue, offset: dataIndex)
                    topicAlias = UInt16(comRes!.res)
                    dataIndex = comRes!.newOffset

                // 3.3.2.3.5 Response Topic
                case CocoaMQTTPropertyName.responseTopic.rawValue:
                    guard let result = unsignedByteToString(data: publishData, offset: dataIndex) else {
                        break
                    }
                    responseTopic = result.resStr
                    dataIndex = result.newOffset

                // 3.3.2.3.6 Correlation Data
                case CocoaMQTTPropertyName.correlationData.rawValue:
                    guard let result = unsignedByteToBinary(data: publishData, offset: dataIndex) else {
                        break
                    }
                    correlationData = result.resStr
                    dataIndex = result.newOffset

                // 3.3.2.3.7 User Property
                case CocoaMQTTPropertyName.userProperty.rawValue:
                    var key: String?
                    var value: String?
                    guard let keyRes = unsignedByteToString(data: publishData, offset: dataIndex) else {
                        break
                    }
                    key = keyRes.resStr
                    dataIndex = keyRes.newOffset

                    guard let valRes = unsignedByteToString(data: publishData, offset: dataIndex) else {
                        break
                    }
                    value = valRes.resStr
                    dataIndex = valRes.newOffset

                    if userProperty == nil {
                        userProperty = [:]
                    }

                    userProperty![key!] = value

                // 3.3.2.3.8 Subscription Identifier
                case CocoaMQTTPropertyName.subscriptionIdentifier.rawValue:
                    let valRes = decodeVariableByteInteger(data: publishData, offset: dataIndex)
                    subscriptionIdentifier = valRes.res
                    dataIndex = valRes.newOffset

                // 3.3.2.3.9 Content Type
                case CocoaMQTTPropertyName.contentType.rawValue:
                    guard let valRes = unsignedByteToString(data: publishData, offset: dataIndex) else {
                        break
                    }
                    contentType = valRes.resStr
                    dataIndex = valRes.newOffset

                default:
                    return
                }
            }
        }
    }
}
