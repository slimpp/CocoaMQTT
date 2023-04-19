//
//  FrameConnack.swift
//  CocoaMQTT
//
//  Created by JianBo on 2019/8/7.
//  Copyright © 2019 emqx.io. All rights reserved.
//

import Foundation

struct FrameConnAck: Frame {
    var packetFixedHeaderType: UInt8 = FrameType.connack.rawValue

    // --- Attributes

    /// MQTT 3.1.1
    var returnCode: CocoaMQTTConnAck?

    /// MQTT 5.0
    var reasonCode: CocoaMQTTCONNACKReasonCode?

    // 3.2.2.1.1 Session Present
    var sessPresent = false

    // --- Attributes End

    // 3.2.2.3 CONNACK Properties
    var connackProperties: MqttDecodeConnAck?
    var propertiesBytes: [UInt8]?
    // 3.2.3 CONNACK Payload
    // The CONNACK packet has no Payload.

    /// MQTT 3.1.1
    init(returnCode: CocoaMQTTConnAck) {
        self.returnCode = returnCode
    }

    /// MQTT 5.0
    init(code: CocoaMQTTCONNACKReasonCode) {
        reasonCode = code
    }
}

extension FrameConnAck {
    func fixedHeader() -> [UInt8] {
        var header = [UInt8]()
        header += [FrameType.connack.rawValue]

        return header
    }

    func variableHeader5() -> [UInt8] {
        return [sessPresent.bit, reasonCode!.rawValue]
    }

    func payload5() -> [UInt8] { return [] }

    func properties() -> [UInt8] { return propertiesBytes ?? [] }

    func allData() -> [UInt8] {
        var allData = [UInt8]()

        allData += fixedHeader()
        allData += variableHeader5()
        allData += properties()
        allData += payload5()

        return allData
    }

    func variableHeader() -> [UInt8] {
        return [sessPresent.bit, returnCode!.rawValue]
    }

    func payload() -> [UInt8] { return [] }
}

extension FrameConnAck: InitialWithBytes {
    init?(packetFixedHeaderType: UInt8, bytes: [UInt8]) {
        guard packetFixedHeaderType == FrameType.connack.rawValue else {
            return nil
        }

        guard bytes.count >= 2 else {
            return nil
        }

        sessPresent = Bool(bit: bytes[0] & 0x01)

        let mqtt5ack = CocoaMQTTCONNACKReasonCode(rawValue: bytes[1])
        reasonCode = mqtt5ack

        let ack = CocoaMQTTConnAck(byte: bytes[1])
        returnCode = ack

        propertiesBytes = bytes
        self.connackProperties = MqttDecodeConnAck()
        self.connackProperties!.properties(connackData: bytes)
    }
}

extension FrameConnAck: CustomStringConvertible {
    var description: String {
        return "CONNACK(code: \(String(describing: reasonCode)), sp: \(sessPresent))"
    }
}
