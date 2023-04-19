//
//  Frame.swift
//  CocoaMQTT
//
//  Created by Feng Lee<feng@eqmtt.io> on 14/8/3.
//  Copyright (c) 2015 emqx.io. All rights reserved.
//

import Foundation

/// Quality of Service levels
@objc public enum CocoaMQTTQoS: UInt8, CustomStringConvertible {
    /// At most once delivery
    case qos0 = 0

    /// At least once delivery
    case qos1

    /// Exactly once delivery
    case qos2

    /// !!! Used SUBACK frame only
    case FAILURE = 0x80

    public var description: String {
        switch self {
        case .qos0: return "qos0"
        case .qos1: return "qos1"
        case .qos2: return "qos2"
        case .FAILURE: return "Failure"
        }
    }
}

extension CocoaMQTTQoS: Comparable {
    public static func < (lhs: CocoaMQTTQoS, rhs: CocoaMQTTQoS) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    public static func <= (lhs: CocoaMQTTQoS, rhs: CocoaMQTTQoS) -> Bool {
        return lhs.rawValue <= rhs.rawValue
    }

    public static func > (lhs: CocoaMQTTQoS, rhs: CocoaMQTTQoS) -> Bool {
        return lhs.rawValue > rhs.rawValue
    }

    public static func >= (lhs: CocoaMQTTQoS, rhs: CocoaMQTTQoS) -> Bool {
        return lhs.rawValue >= rhs.rawValue
    }
}

/// MQTT Frame Type
enum FrameType: UInt8 {
    case reserved = 0x00
    case connect = 0x10
    case connack = 0x20
    case publish = 0x30
    case puback = 0x40
    case pubrec = 0x50
    case pubrel = 0x60
    case pubcomp = 0x70
    case subscribe = 0x80
    case suback = 0x90
    case unsubscribe = 0xA0
    case unsuback = 0xB0
    case pingreq = 0xC0
    case pingresp = 0xD0
    case disconnect = 0xE0
    case auth = 0xF0
}

/// The frame can be initialized with a bytes
protocol InitialWithBytes {
    init?(packetFixedHeaderType: UInt8, bytes: [UInt8])
}

/// MQTT Frame protocol
protocol Frame {
    /// Each MQTT Control Packet contains a fixed header
    /// MQTT 3.1.1
    var packetFixedHeaderType: UInt8 {get set}
    /// MQTT 5.0
    func fixedHeader() -> [UInt8]

    /// Some types of MQTT Control Packets contain a variable header component
    /// MQTT 3.1.1
    func variableHeader() -> [UInt8]

    /// MQTT 5.0
    func variableHeader5() -> [UInt8]

    /// MQTT 5.0 The last field in the Variable Header of the CONNECT, CONNACK,
    /// PUBLISH, PUBACK, PUBREC, PUBREL, PUBCOMP, SUBSCRIBE, SUBACK, UNSUBSCRIBE,
    /// UNSUBACK, DISCONNECT, and AUTH packet is a set of Properties. In the CONNECT
    /// packet there is also an optional set of Properties in the Will Properties field with the Payload.
    func properties() -> [UInt8]

    /// Some MQTT Control Packets contain a payload as the final part of the packet
    /// MQTT 3.1.1
    func payload() -> [UInt8]

    /// MQTT 5.0
    func payload5() -> [UInt8]

    /// fixedHeader + variableHeader + properties + payload
    func allData() -> [UInt8]
}

extension Frame {
    /// Pack struct to binary
    func bytes(version: String) -> [UInt8] {
        if version == "5.0" {
            let fixedHeader = self.fixedHeader()
            let variableHeader5 = self.variableHeader5()
            let payload5 = self.payload5()
            let properties = self.properties()
            let len5 = UInt32(variableHeader5.count + properties.count + payload5.count)

            printDebug("==========================MQTT 5.0==========================")
            printDebug("packetFixedHeaderType \(packetFixedHeaderType)")
            printDebug("fixedHeader \(fixedHeader)")
            printDebug("remainingLen(len: len) \(remainingLen(len: len5))")
            printDebug("variableHeader \(variableHeader5)")
            printDebug("properties \(properties)")
            printDebug("payload \(payload5)")
            printDebug("=============================================================")

            return [packetFixedHeaderType] + remainingLen(len: len5) + variableHeader5 + properties + payload5
        } else {
            let variableHeader = self.variableHeader()
            let payload = self.payload()

            let len = UInt32(variableHeader.count + payload.count)

            printDebug("=========================MQTT 3.1.1=========================")
            printDebug("packetFixedHeaderType \(packetFixedHeaderType)")
            printDebug("remainingLen(len: len) \(remainingLen(len: len))")
            printDebug("variableHeader \(variableHeader)")
            printDebug("payload \(payload)")
            printDebug("=============================================================")

            return [packetFixedHeaderType] + remainingLen(len: len) + variableHeader + payload
        }
    }

    private func remainingLen(len: UInt32) -> [UInt8] {
        var bytes: [UInt8] = []
        var digit: UInt8 = 0

        var len = len
        repeat {
            digit = UInt8(len % 128)
            len /= 128
            // if there are more digits to encode, set the top bit of this digit
            if len > 0 {
                digit = digit | 0x80
            }
            bytes.append(digit)
        } while len > 0

        return bytes
    }
}

/// Fixed Header Attributes
extension Frame {
    /// The Fixed Header consist of the following attritutes
    ///
    /// +---------+----------+-------+--------+
    /// | 7 6 5 4 |     3    |  2 1  | 0      |
    /// +---------+----------+-------+--------+
    /// |  Type   | DUP flag |  QoS  | RETAIN |
    /// +-------------------------------------+

    /// The type of the Frame
    var type: FrameType {
        return  FrameType(rawValue: packetFixedHeaderType & 0xF0)!
    }

    /// Dup flag
    var dup: Bool {
        get {
            return ((packetFixedHeaderType & 0x08) >> 3) == 0 ? false : true
        }
        set {
            packetFixedHeaderType = (packetFixedHeaderType & 0xF7) | (newValue.bit << 3)
        }
    }

    /// Qos level
    var qos: CocoaMQTTQoS {
        get {
            return CocoaMQTTQoS(rawValue: (packetFixedHeaderType & 0x06) >> 1)!
        }
        set {
            packetFixedHeaderType = (packetFixedHeaderType & 0xF9) | (newValue.rawValue << 1)
        }
    }

    /// Retained flag
    var retained: Bool {
        get {
            return (packetFixedHeaderType & 0x01) == 0 ? false : true
        }
        set {
            packetFixedHeaderType = (packetFixedHeaderType & 0xFE) | newValue.bit
        }
    }
}
