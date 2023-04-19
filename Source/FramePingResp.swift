//
//  FramePingResp.swift
//  CocoaMQTT
//
//  Created by JianBo on 2019/8/7.
//  Copyright © 2019 emqx.io. All rights reserved.
//

import Foundation

/// MQTT PINGRESP packet
struct FramePingResp: Frame {
    var packetFixedHeaderType: UInt8 = FrameType.pingresp.rawValue

    init() { /* Nothing to do */ }
}

extension FramePingResp {
    func fixedHeader() -> [UInt8] {
        var header = [UInt8]()
        header += [FrameType.pingresp.rawValue]

        return header
    }

    func variableHeader5() -> [UInt8] { return [] }

    func payload5() -> [UInt8] { return [] }

    func properties() -> [UInt8] { return [] }

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

extension FramePingResp: InitialWithBytes {
    init?(packetFixedHeaderType: UInt8, bytes: [UInt8]) {
        guard packetFixedHeaderType == FrameType.pingresp.rawValue else {
            return nil
        }

        guard bytes.isEmpty else {
            return nil
        }
    }
}

extension FramePingResp: CustomStringConvertible {
    var description: String {
        return "PONG"
    }
}
