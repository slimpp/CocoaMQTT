//
//  FramePubCom.swift
//  CocoaMQTT
//
//  Created by JianBo on 2019/8/7.
//  Copyright © 2019 emqx.io. All rights reserved.
//

import Foundation

/// ublish complete (QoS 2 delivery part 3)
/// The PUBCOMP packet is the response to a PUBREL packet. It is the fourth and final packet of the QoS 2 protocol exchange.
struct FramePubComp: Frame {
    var packetFixedHeaderType: UInt8 = FrameType.pubcomp.rawValue

    // --- Attributes

    var msgid: UInt16

    // --- Attributes End

    // 3.7.2.1 PUBCOMP Reason Code
    var reasonCode: CocoaMQTTPUBCOMPReasonCode?

    // 3.7.2.2 PUBCOMP Properties
    var pubCompProperties: MqttDecodePubComp?
    // 3.7.2.2.2 Reason String
    var reasonString: String?
    // 3.7.2.2.3 User Property
    var userProperties: [String: String]?

    /// MQTT 3.1.1
    init(msgid: UInt16) {
        self.msgid = msgid
    }

    /// MQTT 5.0
    init(msgid: UInt16, reasonCode: CocoaMQTTPUBCOMPReasonCode) {
        self.msgid = msgid
        self.reasonCode = reasonCode
    }
}

extension FramePubComp {
    func fixedHeader() -> [UInt8] {
        var header = [UInt8]()
        header += [FrameType.pubcomp.rawValue]

        return header
    }

    func variableHeader5() -> [UInt8] {
        // 3.7.2 MSB+LSB
        var header = msgid.hlBytes
        // 3.7.2.1 PUBACK Reason Code
        header += [reasonCode!.rawValue]

        // MQTT 5.0
        header += beVariableByteInteger(length: self.properties().count)

        return header
    }

    func payload5() -> [UInt8] { return [] }

    func properties() -> [UInt8] {
        var properties = [UInt8]()

        // 3.7.2.2.2 Reason String
        if let reasonString = self.reasonString {
            properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.reasonString.rawValue, value: reasonString.bytesWithLength)
        }

        // 3.7.2.2.3 User Property
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

extension FramePubComp: InitialWithBytes {
    init?(packetFixedHeaderType: UInt8, bytes: [UInt8]) {
        guard packetFixedHeaderType == FrameType.pubcomp.rawValue else {
            return nil
        }

        guard bytes.count >= 2 else {
            return nil
        }

        msgid = UInt16(bytes[0]) << 8 + UInt16(bytes[1])

        self.pubCompProperties = MqttDecodePubComp()
        self.pubCompProperties!.decodePubComp(fixedHeader: packetFixedHeaderType, pubAckData: bytes)
    }
}

extension FramePubComp: CustomStringConvertible {
    var description: String {
        return "PUBCOMP(id: \(msgid))"
    }
}
