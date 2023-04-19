//
//  FramePubRel.swift
//  CocoaMQTT
//
//  Created by JianBo on 2019/8/7.
//  Copyright © 2019 emqx.io. All rights reserved.
//

import Foundation

/// MQTT PUBREL packet
/// A PUBREL packet is the response to a PUBREC packet. It is the third packet of the QoS 2 protocol exchange.
struct FramePubRel: Frame {
    var packetFixedHeaderType = UInt8(FrameType.pubrel.rawValue + 2)

    // --- Attributes

    var msgid: UInt16

    // --- Attributes End

    // 3.6.2.1 PUBREL Reason Code
    var reasonCode: CocoaMQTTPUBRELReasonCode = .success

    // 3.6.2.2 PUBREL Properties
    var pubRelProperties: MqttDecodePubRel?
    // 3.6.2.2.2 Reason String
    var reasonString: String?
    // 3.6.2.2.3 User Property
    var userProperties: [String: String]?

    init(msgid: UInt16) {
        self.msgid = msgid

        qos = .qos1
    }
}

extension FramePubRel {
    func fixedHeader() -> [UInt8] {
        var header = [UInt8]()
        header += [FrameType.pubrel.rawValue]

        return header
    }

    func variableHeader5() -> [UInt8] {
        // 3.6.2 MSB+LSB
        var header = msgid.hlBytes
        // 3.6.2.1 PUBACK Reason Code
        header += [reasonCode.rawValue]
        // MQTT 5.0
        header += beVariableByteInteger(length: self.properties().count)

        return header
    }

    func payload5() -> [UInt8] { return [] }

    func properties() -> [UInt8] {
        var properties = [UInt8]()

        // 3.6.2.2.2 Reason String
        if let reasonString = self.reasonString {
            properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.reasonString.rawValue, value: reasonString.bytesWithLength)
        }

        // 3.6.2.2.3 User Property
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

extension FramePubRel: InitialWithBytes {
    init?(packetFixedHeaderType: UInt8, bytes: [UInt8]) {
        guard packetFixedHeaderType == 0x62 else {
            return nil
        }
        guard bytes.count >= 2 else {
            return nil
        }

        self.packetFixedHeaderType = packetFixedHeaderType
        msgid = UInt16(bytes[0]) << 8 + UInt16(bytes[1])

        self.pubRelProperties = MqttDecodePubRel()
        self.pubRelProperties!.decodePubRel(fixedHeader: packetFixedHeaderType, pubAckData: bytes)
    }
}

extension FramePubRel: CustomStringConvertible {
    var description: String {
        return "PUBREL(id: \(msgid))"
    }
}
