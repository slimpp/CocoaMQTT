//
//  FramePingReq.swift
//  CocoaMQTT
//
//  Created by JianBo on 2019/8/7.
//  Copyright © 2019 emqx.io. All rights reserved.
//

import Foundation

struct FramePingReq: Frame {
    var packetFixedHeaderType: UInt8 = FrameType.pingreq.rawValue

    init() { /* Nothing to do */ }
}

extension FramePingReq {
    func fixedHeader() -> [UInt8] {
        var header = [UInt8]()
        header += [FrameType.pingreq.rawValue]

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

extension FramePingReq: CustomStringConvertible {
    var description: String {
        return "PING"
    }
}
