//
//  FrameUnsubscribe.swift
//  CocoaMQTT
//
//  Created by JianBo on 2019/8/7.
//  Copyright © 2019 emqx.io. All rights reserved.
//

import Foundation

/// MQTT UNSUBSCRIBE packet
struct FrameUnsubscribe: Frame {
    var packetFixedHeaderType = UInt8(FrameType.unsubscribe.rawValue + 2)

    // --- Attributes

    var msgid: UInt16?

    /// MQTT 3.1.1
    var topics: [String]?

    /// MQTT 5.0
    var topicFilters: [MqttSubscription]?

    // --- Attribetes end

    // 3.10.2.1.2 User Property
    var userProperty: [String: String]?

    /// MQTT 3.1.1
    init(msgid: UInt16, topics: [String]) {
        self.msgid = msgid
        self.topics = topics

        qos = CocoaMQTTQoS.qos1
    }

    /// MQTT 5.0
    init(msgid: UInt16, topics: [MqttSubscription]) {
        self.msgid = msgid
        self.topicFilters = topics

        qos = CocoaMQTTQoS.qos1
    }
}

extension FrameUnsubscribe {
    func fixedHeader() -> [UInt8] {
        var header = [UInt8]()
        header += [FrameType.unsubscribe.rawValue]

        return header
    }

    func variableHeader5() -> [UInt8] {
        // MQTT 5.0
        var header = [UInt8]()
        header = msgid!.hlBytes
        header += beVariableByteInteger(length: self.properties().count)
        return header
    }

    func payload5() -> [UInt8] {
        var payload = [UInt8]()

        for subscription in topicFilters! {
            subscription.subscriptionOptions = false
            payload += subscription.subscriptionData
        }

        return payload
    }

    func properties() -> [UInt8] {
        var properties = [UInt8]()

        // 3.10.2.1.2 User Property
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

        for t in topics! {
            payload += t.bytesWithLength
        }

        return payload
    }
}

extension FrameUnsubscribe: CustomStringConvertible {
    var description: String {
        var protocolVersion = ""
        if let storage = CocoaMQTTStorage() {
            protocolVersion = storage.queryMQTTVersion()
        }

        if protocolVersion == "5.0" {
            var desc = ""
            if let unwrappedList = topicFilters, !unwrappedList.isEmpty {
                for subscription in unwrappedList {
                    desc += "UNSUBSCRIBE(id: \(String(describing: subscription.topic)), topics: \(subscription.topic))  "
                }
            }
            return desc
        } else {
            return "UNSUBSCRIBE(id: \(String(describing: msgid)), topics: \(String(describing: topics)))"
        }
    }
}
