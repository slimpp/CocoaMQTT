//
//  MqttDecodeUnsubAck.swift
//  CocoaMQTT
//
//  Created by liwei wang on 2021/8/16.
//

import Foundation

public class MqttDecodeUnsubAck: NSObject {
    var totalCount = 0
    var dataIndex = 0
    var propertyLength: Int = 0

    public var reasonCodes: [CocoaMQTTUNSUBACKReasonCode] = []

    public var msgid: UInt16 = 0
    public var reasonString: String?
    public var userProperty: [String: String]?

    public func decodeUnSubAck(fixedHeader: UInt8, pubAckData: [UInt8]) {
        totalCount = pubAckData.count
        dataIndex = 0
        // msgid
        let msgidResult = integerCompute(data: pubAckData, formatType: FormatInt.formatUint16.rawValue, offset: dataIndex)
        msgid = UInt16(msgidResult!.res)
        dataIndex = msgidResult!.newOffset

        var protocolVersion = ""
        if let storage = CocoaMQTTStorage() {
            protocolVersion = storage.queryMQTTVersion()
        }

        if protocolVersion == "5.0" {
            // 3.11.2.1 UNSUBACK Properties
            // 3.11.2.1.1 Property Length
            let propertyLengthVariableByteInteger = decodeVariableByteInteger(data: pubAckData, offset: dataIndex)
            propertyLength = propertyLengthVariableByteInteger.res
            dataIndex = propertyLengthVariableByteInteger.newOffset
            let occupyIndex = dataIndex

            while dataIndex < occupyIndex + propertyLength {
                let resVariableByteInteger = decodeVariableByteInteger(data: pubAckData, offset: dataIndex)
                dataIndex = resVariableByteInteger.newOffset
                let propertyNameByte = resVariableByteInteger.res
                guard let propertyName = CocoaMQTTPropertyName(rawValue: UInt8(propertyNameByte)) else {
                    break
                }

                switch propertyName.rawValue {
                // 3.11.2.1.2 Reason String
                case CocoaMQTTPropertyName.reasonString.rawValue:
                    guard let result = unsignedByteToString(data: pubAckData, offset: dataIndex) else {
                        break
                    }
                    reasonString = result.resStr
                    dataIndex = result.newOffset

                // 3.11.2.1.3 User Property
                case CocoaMQTTPropertyName.userProperty.rawValue:
                    var key: String?
                    var value: String?
                    guard let keyRes = unsignedByteToString(data: pubAckData, offset: dataIndex) else {
                        break
                    }
                    key = keyRes.resStr
                    dataIndex = keyRes.newOffset

                    guard let valRes = unsignedByteToString(data: pubAckData, offset: dataIndex) else {
                        break
                    }
                    value = valRes.resStr
                    dataIndex = valRes.newOffset

                    userProperty![key!] = value

                default:
                    return
                }
            }
        }

        if dataIndex < totalCount {
            while dataIndex < totalCount {
                guard let reasonCode = CocoaMQTTUNSUBACKReasonCode(rawValue: pubAckData[dataIndex]) else {
                    return
                }
                reasonCodes.append(reasonCode)
                dataIndex += 1
            }
        }
    }
}
