//
//  MqttDecodePubRel.swift
//  CocoaMQTT
//
//  Created by liwei wang on 2021/8/9.
//

import Foundation

public class MqttDecodePubRel: NSObject {
    var totalCount = 0
    var dataIndex = 0
    var propertyLength: Int = 0

    public var reasonCode: CocoaMQTTPUBRELReasonCode?
    public var msgid: UInt16 = 0
    public var reasonString: String?
    public var userProperty: [String: String]?

    public func decodePubRel(fixedHeader: UInt8, pubAckData: [UInt8]) {
        totalCount = pubAckData.count
        dataIndex = 0
        // msgid
        let msgidResult = integerCompute(data: pubAckData, formatType: FormatInt.formatUint16.rawValue, offset: dataIndex)
        msgid = UInt16(msgidResult!.res)
        dataIndex = msgidResult!.newOffset

        // 3.6.2.1 PUBREL Reason Code

        // The Reason Code and Property Length can be omitted if the Reason Code is 0x00 (Success)
        // and there are no Properties. In this case the PUBACK has a Remaining Length of 2.
        if dataIndex + 1 > pubAckData.count {
            return
        }

        guard let ack = CocoaMQTTPUBRELReasonCode(rawValue: pubAckData[dataIndex]) else {
            return
        }
        reasonCode = ack
        dataIndex += 1

        var protocolVersion = ""
        if let storage = CocoaMQTTStorage() {
            protocolVersion = storage.queryMQTTVersion()
        }

        if protocolVersion == "5.0" {
            // 3.6.2.2 PUBREL Properties
            // 3.6.2.2.1 Property Length
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
                // 3.6.2.2.2 Reason String
                case CocoaMQTTPropertyName.reasonString.rawValue:
                    guard let result = unsignedByteToString(data: pubAckData, offset: dataIndex) else {
                        break
                    }
                    reasonString = result.resStr
                    dataIndex = result.newOffset

                // 3.6.2.2.3 User Property
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
    }
}
