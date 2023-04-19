//
//  FramePubRec.swift
//  CocoaMQTT
//
//  Created by JianBo on 2019/8/7.
//  Copyright © 2019 emqx.io. All rights reserved.
//

import Foundation

/// MQTT PUBREC packet
struct FramePubRec: Frame {
    var packetFixedHeaderType: UInt8 = FrameType.pubrec.rawValue

    // --- Attributes

    var msgid: UInt16

    // --- Attributes End

    // 3.5.2.1 PUBREC Reason Code
    var reasonCode: CocoaMQTTPUBRECReasonCode?

    // 3.5.2.2 PUBREC Properties
    var pubRecProperties: MqttDecodePubRec?
    // 3.5.2.2.2 Reason String
    var reasonString: String?
    // 3.5.2.2.3 User Property
    var userProperties: [String: String]?

    /// MQTT 3.1.1
    init(msgid: UInt16) {
        self.msgid = msgid
    }

    /// MQTT 5.0
    init(msgid: UInt16, reasonCode: CocoaMQTTPUBRECReasonCode) {
        self.msgid = msgid
        self.reasonCode = reasonCode
    }
}

extension FramePubRec {
    func fixedHeader() -> [UInt8] {
        var header = [UInt8]()
        header += [FrameType.pubrec.rawValue]

        return header
    }

    func variableHeader5() -> [UInt8] {
        // 3.5.2 MSB+LSB
        var header = msgid.hlBytes
        // 3.5.2.1 PUBACK Reason Code
        header += [reasonCode!.rawValue]

        // MQTT 5.0
        header += beVariableByteInteger(length: self.properties().count)

        return header
    }

    func payload5() -> [UInt8] { return [] }

    func properties() -> [UInt8] {
        var properties = [UInt8]()

        // 3.5.2.2.2 Reason String
        if let reasonString = self.reasonString {
            properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.reasonString.rawValue, value: reasonString.bytesWithLength)
        }

        // 3.5.2.2.3 User Property
        if let userProperty = self.userProperties {
            for (key, value) in userProperty {
                properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.userProperty.rawValue, value: key.bytesWithLength + value.bytesWithLength)
            }
        }

        return properties
    }

    func allData() -> [UInt8] {
        var allData = [UInt8]()

        allData += fixedHeader()
        allData += variableHeader5()
        allData += properties()
        allData += payload5()

        return allData
    }

    func variableHeader() -> [UInt8] { return msgid.hlBytes }

    func payload() -> [UInt8] { return [] }
}

extension FramePubRec: InitialWithBytes {
    init?(packetFixedHeaderType: UInt8, bytes: [UInt8]) {
        guard packetFixedHeaderType == FrameType.pubrec.rawValue else {
            return nil
        }
        guard bytes.count >= 2 else {
            return nil
        }

        msgid = UInt16(bytes[0]) << 8 + UInt16(bytes[1])

        self.pubRecProperties = MqttDecodePubRec()
        self.pubRecProperties!.decodePubRec(fixedHeader: packetFixedHeaderType, pubAckData: bytes)
    }
}

extension FramePubRec: CustomStringConvertible {
    var description: String {
        return "PUBREC(id: \(msgid))"
    }
}
