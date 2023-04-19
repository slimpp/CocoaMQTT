//
//  FrameSubAck.swift
//  CocoaMQTT
//
//  Created by JianBo on 2019/8/7.
//  Copyright © 2019 emqx.io. All rights reserved.
//

import Foundation

/// MQTT SUBACK packet
struct FrameSubAck: Frame {
    var packetFixedHeaderType: UInt8 = FrameType.suback.rawValue

    // --- Attributes

    var msgid: UInt16

    var grantedQos: [CocoaMQTTQoS]

    // --- Attributes End

    // 3.9.2.1.2 Reason String
    var reasonString: String?
    // 3.9.2.1.3 User Property
    var userProperties: [String: String]?
    // 3.9.3 The order of Reason Codes in the SUBACK packet MUST match the order of Topic Filters in the SUBSCRIBE packet [MQTT-3.9.3-1].
    var reasonCodes: [CocoaMQTTSUBACKReasonCode]?

    // 3.9.2.1 SUBACK Properties
    var subAckProperties: MqttDecodeSubAck?

    init(msgid: UInt16, grantedQos: [CocoaMQTTQoS]) {
        self.msgid = msgid
        self.grantedQos = grantedQos
    }
}

extension FrameSubAck {
    func fixedHeader() -> [UInt8] {
        var header = [UInt8]()
        header += [FrameType.suback.rawValue]

        return header
    }

    func variableHeader5() -> [UInt8] { return msgid.hlBytes }

    func payload5() -> [UInt8] {
        var payload = [UInt8]()

        for qos in grantedQos {
            payload.append(qos.rawValue)
        }

        return payload
    }

    func properties() -> [UInt8] { return [] }

    func allData() -> [UInt8] {
        var allData = [UInt8]()

        allData += fixedHeader()
        allData += variableHeader5()
        allData += properties()
        allData += payload5()

        return allData
    }

    func variableHeader() -> [UInt8] { return msgid.hlBytes }

    func payload() -> [UInt8] {
        var payload = [UInt8]()

        for qos in grantedQos {
            payload.append(qos.rawValue)
        }

        return payload
    }
}

extension FrameSubAck: InitialWithBytes {
    init?(packetFixedHeaderType: UInt8, bytes: [UInt8]) {
        self.packetFixedHeaderType = packetFixedHeaderType

        var protocolVersion = ""
        if let storage = CocoaMQTTStorage() {
            protocolVersion = storage.queryMQTTVersion()
        }

        if protocolVersion == "5.0" {
            // the bytes length must bigger than 3
            guard bytes.count >= 4 else {
                return nil
            }

            self.msgid = UInt16(bytes[0]) << 8 + UInt16(bytes[1])
            self.grantedQos = []
            for i in 3 ..< bytes.count {
                guard let qos = CocoaMQTTQoS(rawValue: bytes[i]) else {
                    return nil
                }
                self.grantedQos.append(qos)
            }

            self.reasonCodes = [CocoaMQTTSUBACKReasonCode]()
            for i in 3 ..< bytes.count {
                guard let qos = CocoaMQTTSUBACKReasonCode(rawValue: bytes[i]) else {
                    return nil
                }
                self.reasonCodes! += [qos]
            }

            self.subAckProperties = MqttDecodeSubAck()
            self.subAckProperties!.decodeSubAck(fixedHeader: packetFixedHeaderType, pubAckData: bytes)
        } else {
            // the bytes length must bigger than 3
            guard bytes.count >= 3 else {
                return nil
            }

            self.msgid = UInt16(bytes[0]) << 8 + UInt16(bytes[1])
            self.grantedQos = []
            for i in 2 ..< bytes.count {
                guard let qos = CocoaMQTTQoS(rawValue: bytes[i]) else {
                    return nil
                }
                self.grantedQos.append(qos)
            }
        }
    }
}

extension FrameSubAck: CustomStringConvertible {
    var description: String {
        return "SUBACK(id: \(msgid))"
    }
}
