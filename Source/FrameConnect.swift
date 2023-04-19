//
//  ConnectFrame.swift
//  CocoaMQTT
//
//  Created by JianBo on 2019/8/7.
//  Copyright © 2019 emqx.io. All rights reserved.
//

import Foundation

/// MQTT CONNECT Frame
struct FrameConnect: Frame {
    var packetFixedHeaderType: UInt8 = FrameType.connect.rawValue

    /// MQTT 3.1.1
    private let kProtocolLevel = UInt8(4)
    // private let kProtocolVersion: String  = "MQTT/3.1.1"
    private let kProtocolMagic: String = "MQTT"

    // --- Attributes

    // 3.1.2.1

    let protocolName: String = "MQTT"
    // 3.1.2.2 Protocol Version
    let protocolVersion = UInt8(5)

    // 3.1.2.5 Will Flag
    var willMsg: CocoaMQTTMessage?
    var willMsg5: CocoaMQTT5Message?
    // 3.1.2.6 Will QoS
    var willQoS: UInt8?
    // 3.1.2.7 Will Retain
    var willRetain = true
    // 3.1.2.8 User Name Flag
    var username: String?
    // 3.1.2.9 Password Flag
    var password: String?
    // 3.1.2.10 Keep Alive
    var keepAlive: UInt16 = 10
    var cleansess = true

    // 3.1.2
    // 3.1.2.11 CONNECT Properties
    var connectProperties: MqttConnectProperties?

    var authenticationData: Data?

    // 3.1.3.1 Client Identifier (ClientID)
    var clientID: String

    // --- Attributes End

    init(clientID: String) {
        self.clientID = clientID
    }
}

extension FrameConnect {
    func fixedHeader() -> [UInt8] {
        var header = [UInt8]()
        header += [FrameType.connect.rawValue]

        return header
    }

    func variableHeader5() -> [UInt8] {
        var header = [UInt8]()
        var flags = ConnFlags()

        // 3.1.2.1 Protocol Name
        header += protocolName.bytesWithLength

        // 3.1.2.2 Protocol Version
        header.append(protocolVersion)

        // 3.1.2.3 Connect Flags
        if let will = willMsg5 {
            flags.flagWill = true
            flags.flagWillQoS = will.qos.rawValue
            flags.flagWillRetain = will.retained
        }

        if username != nil {
            flags.flagUsername = true

            // Append password attribute if username presented
            if password != nil {
                flags.flagPassword = true
            }
        }

        flags.flagCleanSession = cleansess

        header.append(flags.rawValue)
        header += keepAlive.hlBytes

        // MQTT 5.0
        header += beVariableByteInteger(length: self.properties().count)

        return header
    }

    func properties() -> [UInt8] {
        return connectProperties?.properties ?? []
    }

    func payload5() -> [UInt8] {
        var payload = [UInt8]()

        payload += clientID.bytesWithLength

        if let will = willMsg5 {
            payload += beVariableByteInteger(length: willMsg5!.properties.count)
            payload += will.properties
            payload += will.topic.bytesWithLength
            payload += UInt16(will.payload.count).hlBytes
            payload += will.payload
        }

        if let username = username {
            payload += username.bytesWithLength

            // Append password attribute if username presented
            if let password = password {
                payload += password.bytesWithLength
            }
        }

        return payload
    }

    func allData() -> [UInt8] {
        var allData = [UInt8]()

        allData += fixedHeader()
        allData += variableHeader5()
        allData += properties()
        allData += payload5()

        return allData
    }

    func variableHeader() -> [UInt8] {
        var header = [UInt8]()
        var flags = ConnFlags()

        // variable header
        header += kProtocolMagic.bytesWithLength
        header.append(kProtocolLevel)

        if let will = willMsg {
            flags.flagWill = true
            flags.flagWillQoS = will.qos.rawValue
            flags.flagWillRetain = will.retained
        }

        if username != nil {
            flags.flagUsername = true

            // Append password attribute if username presented
            if password != nil {
                flags.flagPassword = true
            }
        }

        flags.flagCleanSession = cleansess

        header.append(flags.rawValue)
        header += keepAlive.hlBytes

        return header
    }

    func payload() -> [UInt8] {
        var payload = [UInt8]()

        payload += clientID.bytesWithLength

        if let will = willMsg {
            payload += will.topic.bytesWithLength
            payload += UInt16(will.payload.count).hlBytes
            payload += will.payload
        }
        if let username = username {
            payload += username.bytesWithLength

            // Append password attribute if username presented
            if let password = password {
                payload += password.bytesWithLength
            }
        }

        return payload
    }
}

extension FrameConnect: CustomStringConvertible {
    var description: String {
        return "CONNECT(id: \(clientID), username: \(username ?? "nil"), " +
               "password: \(password ?? "nil"), keepAlive : \(keepAlive), " +
               "cleansess: \(cleansess))"
    }
}

/// Connect Flags
private struct ConnFlags {
    /// These Flags consist of following flags:
    ///
    ///    +----------+----------+------------+--------------------+--------------+----------+
    ///    |     7    |    6     |      5     |  4   3  |     2    |       1      |     0    |
    ///    +----------+----------+------------+---------+----------+--------------+----------+
    ///    | username | password | willretain | willqos | willflag | cleansession | reserved |
    ///    +----------+----------+------------+---------+----------+--------------+----------+
    ///
    var rawValue: UInt8 = 0

    var flagUsername: Bool {
        get {
            return Bool(bit: (rawValue >> 7) & 0x01)
        }

        set {
            rawValue = (rawValue & 0x7F) | (newValue.bit << 7)
        }
    }

    var flagPassword: Bool {
        get {
            return Bool(bit: (rawValue >> 6) & 0x01)
        }

        set {
            rawValue = (rawValue & 0xBF) | (newValue.bit << 6)
        }
    }

    var flagWillRetain: Bool {
        get {
            return Bool(bit: (rawValue >> 5) & 0x01)
        }

        set {
            rawValue = (rawValue & 0xDF) | (newValue.bit << 5)
        }
    }

    var flagWillQoS: UInt8 {
        get {
            return (rawValue >> 3) & 0x03
        }

        set {
            rawValue = (rawValue & 0xE7) | (newValue << 3)
        }
    }

    var flagWill: Bool {
        get {
            return Bool(bit: (rawValue >> 2) & 0x01)
        }

        set {
            rawValue = (rawValue & 0xFB) | (newValue.bit << 2)
        }
    }

    var flagCleanSession: Bool {
        get {
            return Bool(bit: (rawValue >> 1) & 0x01)
        }

        set {
            rawValue = (rawValue & 0xFD) | (newValue.bit << 1)
        }
    }
}
