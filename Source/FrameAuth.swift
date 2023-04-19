//
//  FrameAuth.swift
//  CocoaMQTT
//
//  Created by liwei wang on 2021/7/4.
//

import Foundation

struct FrameAuth: Frame {
    var packetFixedHeaderType: UInt8 = FrameType.auth.rawValue

    // 3.15.2.1 Authenticate Reason Code
    var sendReasonCode: CocoaMQTTAUTHReasonCode?
    var receiveReasonCode: CocoaMQTTAUTHReasonCode?

    // 3.15.2.2 AUTH Properties
    var authProperties: MqttAuthProperties?

    init(reasonCode: CocoaMQTTAUTHReasonCode, authProperties: MqttAuthProperties) {
        self.sendReasonCode = reasonCode
        self.authProperties = authProperties
    }
}

extension FrameAuth {
    func fixedHeader() -> [UInt8] {
        var header = [UInt8]()
        header += [FrameType.auth.rawValue]
        // header += [UInt8(variableHeader5().count)]

        return header
    }

    func variableHeader5() -> [UInt8] {
        var header = [UInt8]()
        header += [sendReasonCode!.rawValue]
        // MQTT 5.0
        header += beVariableByteInteger(length: self.properties().count)

        return header
    }

    func payload5() -> [UInt8] { return []}

    func properties() -> [UInt8] {
        return authProperties?.properties ?? []
    }

    func allData() -> [UInt8] {
        var allData = [UInt8]()

        allData += fixedHeader()
        allData += variableHeader5()
        allData += properties()
        allData += payload5()

        return allData
    }

    func variableHeader() -> [UInt8] { return [] }

    func payload() -> [UInt8] { return [] }
}

extension FrameAuth: InitialWithBytes {
    init?(packetFixedHeaderType: UInt8, bytes: [UInt8]) {
        receiveReasonCode = CocoaMQTTAUTHReasonCode(rawValue: bytes[0])
    }
}
