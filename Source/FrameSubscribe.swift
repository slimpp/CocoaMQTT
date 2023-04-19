//
//  FrameSubscribe.swift
//  CocoaMQTT
//
//  Created by JianBo on 2019/8/7.
//  Copyright © 2019 emqx.io. All rights reserved.
//

import Foundation

/// MQTT SUBSCRIBE Frame
struct FrameSubscribe: Frame {
    var packetFixedHeaderType = UInt8(FrameType.subscribe.rawValue + 2)

    // --- Attributes

    var msgid: UInt16?

    var topics: [(String, CocoaMQTTQoS)]?

    // --- Attributes End

    // 3.8.2 SUBSCRIBE Variable Header
    var packetIdentifier: UInt16?

    // 3.8.2.1.2 Subscription Identifier
    var subscriptionIdentifier: UInt32?

    // 3.8.2.1.3 User Property
    var userProperty: [String: String]?

    // 3.8.3 SUBSCRIBE Payload
    var topicFilters: [MqttSubscription]?

    /// MQTT 3.1.1
    init(msgid: UInt16, topic: String, reqos: CocoaMQTTQoS) {
        self.init(msgid: msgid, topics: [(topic, reqos)])
    }

    init(msgid: UInt16, topics: [(String, CocoaMQTTQoS)]) {
        packetFixedHeaderType = FrameType.subscribe.rawValue
        self.msgid = msgid
        self.topics = topics

        qos = CocoaMQTTQoS.qos1
    }

    /// MQTT 5.0
    init(msgid: UInt16, subscriptionList: [MqttSubscription]) {
        self.msgid = msgid
        self.topicFilters = subscriptionList
    }
}

extension FrameSubscribe {
    func fixedHeader() -> [UInt8] {
        var header = [UInt8]()
        header += [FrameType.subscribe.rawValue]

        return header
    }

    func variableHeader5() -> [UInt8] {
        // 3.8.2 SUBSCRIBE Variable Header
        // The Variable Header of the SUBSCRIBE Packet contains the following fields in the order: Packet Identifier, and Properties.

        // MQTT 5.0
        var header = [UInt8]()
        header = msgid!.hlBytes
        header += beVariableByteInteger(length: self.properties().count)

        return header
    }

    func payload5() -> [UInt8] {
        var payload = [UInt8]()

        for subscription in self.topicFilters! {
            subscription.subscriptionOptions = true
            payload += subscription.subscriptionData
        }

        return payload
    }

    func properties() -> [UInt8] {
        var properties = [UInt8]()

        // 3.8.2.1.2 Subscription Identifier
        if let subscriptionIdentifier = self.subscriptionIdentifier {
            properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.subscriptionIdentifier.rawValue, value: subscriptionIdentifier.byteArrayLittleEndian)
        }

        // 3.8.2.1.3 User Property
        if let userProperty = self.userProperty {
            let dictValues = [String](userProperty.values)
            for (value) in dictValues {
                properties += getMQTTPropertyData(type: CocoaMQTTPropertyName.userProperty.rawValue, value: value.bytesWithLength)
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

    func variableHeader() -> [UInt8] { return msgid!.hlBytes }

    func payload() -> [UInt8] {
        var payload = [UInt8]()

        for (topic, qos) in topics! {
            payload += topic.bytesWithLength
            payload.append(qos.rawValue)
        }

        return payload
    }
}

extension FrameSubscribe: CustomStringConvertible {
    var description: String {
        var protocolVersion = ""
        if let storage = CocoaMQTTStorage() {
            protocolVersion = storage.queryMQTTVersion()
        }

        if protocolVersion == "5.0" {
            var desc = ""
            if let unwrappedList = topicFilters, !unwrappedList.isEmpty {
                for subscription in unwrappedList {
                    desc += "SUBSCRIBE(id: \(String(describing: msgid)), topics: \(subscription.topic))  "
                }
            }
            return desc
        } else {
            return "SUBSCRIBE(id: \(String(describing: msgid)), topics: \(String(describing: topics)))"
        }
    }
}
