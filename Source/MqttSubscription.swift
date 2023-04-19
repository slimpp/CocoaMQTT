//
//  MqttSubscription.swift
//  CocoaMQTT
//
//  Created by liwei wang on 2021/7/15.
//

import Foundation

/// 3.8.3.1 Subscription Options
public class MqttSubscription {
    public var topic: String
    public var qos = CocoaMQTTQoS.qos1
    public var noLocal = false
    public var retainAsPublished = false
    public var retainHandling: CocoaRetainHandlingOption
    public var subscriptionOptions = false

    public init(topic: String) {
        self.topic = topic
        self.qos = CocoaMQTTQoS.qos1
        self.noLocal = false
        self.retainAsPublished = false
        self.retainHandling = CocoaRetainHandlingOption.none
    }

    public init(topic: String, qos: CocoaMQTTQoS) {
        self.topic = topic
        self.qos = qos
        self.noLocal = false
        self.retainAsPublished = false
        self.retainHandling = CocoaRetainHandlingOption.none
    }

    var subscriptionData: [UInt8] {
        var data = [UInt8]()

        data += topic.bytesWithLength

        var options: Int = 0
        switch self.qos {
        case .qos0:
            options = options | 0b0000_0000
        case .qos1:
            options = options | 0b0000_0001
        case .qos2:
            options = options | 0b0000_0010
        default:
            printDebug("topicFilter qos failure")
        }

        switch self.noLocal {
        case true:
            options = options | 0b0000_0100
        case false:
            options = options | 0b0000_0000
        }

        switch self.retainAsPublished {
        case true:
            options = options | 0b0000_1000
        case false:
            options = options | 0b0000_0000
        }

        switch self.retainHandling {
        case CocoaRetainHandlingOption.none:
            options = options | 0b0010_0000
        case CocoaRetainHandlingOption.sendOnlyWhenSubscribeIsNew:
            options = options | 0b0001_0000
        case CocoaRetainHandlingOption.sendOnSubscribe:
            options = options | 0b0000_0000
        }

        if subscriptionOptions {
            data += [UInt8(options)]
        }

        return data
    }
}
