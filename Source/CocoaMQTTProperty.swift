//
//  CocoaMQTTPropertyType.swift
//  CocoaMQTT
//
//  Created by liwei wang on 2021/7/6.
//

import Foundation

public enum CocoaMQTTPropertyName: UInt8 {
    case payloadFormatIndicator = 0x01
    case willExpiryInterval = 0x02
    case contentType = 0x03
    case responseTopic = 0x08
    case correlationData = 0x09
    case subscriptionIdentifier = 0x0B
    case sessionExpiryInterval = 0x11
    case assignedClientIdentifier = 0x12
    case serverKeepAlive = 0x13
    case authenticationMethod = 0x15
    case authenticationData = 0x16
    case requestProblemInformation = 0x17
    case willDelayInterval = 0x18
    case requestResponseInformation = 0x19
    case responseInformation = 0x1A
    case serverReference = 0x1C
    case reasonString = 0x1F
    case receiveMaximum = 0x21
    case topicAliasMaximum = 0x22
    case topicAlias = 0x23
    case maximumQoS = 0x24
    case retainAvailable = 0x25
    case userProperty = 0x26
    case maximumPacketSize = 0x27
    case wildcardSubscriptionAvailable = 0x28
    case subscriptionIdentifiersAvailable = 0x29
    case sharedSubscriptionAvailable = 0x2A
}

public enum FormatInt: Int {
    case formatUint8 = 0x11
    case formatUint16 = 0x12
    case formatUint32 = 0x14
    case formatSint8 = 0x21
    case formatSint16 = 0x22
    case formatSint32 = 0x24
}

func getMQTTPropertyData(type: UInt8, value: [UInt8]) -> [UInt8] {
    var properties = [UInt8]()
    properties.append(UInt8(type))
    properties += value
    return properties
}

func getMQTTPropertyLength(type: UInt8, value: [UInt8]) -> [UInt8] {
    var properties = [UInt8]()
    properties.append(UInt8(type))
    properties += value
    return properties
}

func integerCompute(data: [UInt8], formatType: Int, offset: Int) -> (res: Int, newOffset: Int)? {
    switch formatType {
    case FormatInt.formatUint8.rawValue:
        return (unsignedByteToInt(data: data[offset]), offset + 1)
    case FormatInt.formatUint16.rawValue:
        return (unsignedBytesToInt(data0: data[offset], data1: data[offset + 1]), offset + 2)
    case FormatInt.formatUint32.rawValue:
        return (unsignedBytesToInt(data0: data[offset], data1: data[offset + 1], data2: data[offset + 2], data3: data[offset + 3]), offset + 4)
    case FormatInt.formatSint8.rawValue:
        return (unsignedToSigned(unsign: unsignedByteToInt(data: data[offset]), size: 8), offset + 1)
    case FormatInt.formatSint16.rawValue:
        return (unsignedToSigned(unsign: unsignedBytesToInt(data0: data[offset], data1: data[offset + 1]), size: 16), offset + 2)
    case FormatInt.formatSint32.rawValue:
        return (unsignedToSigned(unsign: unsignedBytesToInt(
            data0: data[offset],
            data1: data[offset + 1],
            data2: data[offset + 2],
            data3: data[offset + 3]), size: 32), offset + 4)
    default:
        printDebug("integerCompute nothing")
    }

    return nil
}

func unsignedByteToInt(data: UInt8) -> (Int) {
    return (Int)(data & 0xFF)
}

func unsignedBytesToInt(data0: UInt8, data1: UInt8) -> (Int) {
    return (unsignedByteToInt(data: data0) << 8) + unsignedByteToInt(data: data1)
}

func unsignedBytesToInt(data0: UInt8, data1: UInt8, data2: UInt8, data3: UInt8) -> (Int) {
    return unsignedByteToInt(data: data3) +
        (unsignedByteToInt(data: data2) << 8) +
        (unsignedByteToInt(data: data1) << 16) +
        (unsignedByteToInt(data: data0) << 24)
}

func unsignedToSigned(unsign: NSInteger, size: NSInteger) -> (Int) {
    var res = unsign
    if (res & (1 << size - 1)) != 0 {
        res = -1 * ((1 << size - 1) - (res & ((1 << size - 1) - 1)))
    }
    return res
}

func unsignedByteToString(data: [UInt8], offset: Int) -> (resStr: String, newOffset: Int)? {
    var newOffset = offset

    if offset + 1 > data.count {
        return nil
    }

    var length = 0
    let comRes = integerCompute(data: data, formatType: FormatInt.formatUint16.rawValue, offset: newOffset)
    length = comRes!.res
    newOffset = comRes!.newOffset

    var stringData = Data()
    for _ in 0 ..< length {
        stringData.append(data[newOffset])
        newOffset += 1
    }
    guard let res = String(data: stringData, encoding: .utf8) else {
        return nil
    }

    return (res, newOffset)
}

func unsignedByteToBinary(data: [UInt8], offset: Int) -> (resStr: [UInt8], newOffset: Int)? {
    var newOffset = offset

    if offset + 1 > data.count {
        return nil
    }

    var length = 0
    let comRes = integerCompute(data: data, formatType: FormatInt.formatUint16.rawValue, offset: newOffset)
    length = comRes!.res
    newOffset = comRes!.newOffset

    var res = [UInt8]()
    for _ in 0 ..< length {
        res.append(data[newOffset])
        newOffset += 1
    }

    return (res, newOffset)
}

// 1.5.5 Variable Byte Integer
// The Variable Byte Integer is encoded using an encoding scheme which uses a single byte
// for values up to 127. Larger values are handled as follows. The least significant seven
// bits of each byte encode the data, and the most significant bit is used to indicate
// whether there are bytes following in the representation. Thus, each byte encodes 128
// values and a "continuation bit". The maximum number of bytes in the Variable Byte Integer
// field is four. The encoded value MUST use the minimum number of bytes necessary to
// represent the value [MQTT-1.5.5-1]. This is shown in Table 1‑1 Size of Variable Byte Integer.
func decodeVariableByteInteger(data: [UInt8], offset: Int) -> (res: Int, newOffset: Int) {
    var newOffset = offset
    var count = 0
    var res: Int = 0
    while newOffset < data.count {
        let newValue = Int(data[newOffset] & 0x7f) << count
        res += newValue
        if (data[newOffset] & 0x80) == 0 || count >= 21 {
            newOffset += 1
            break
        }
        newOffset += 1
        count += 7
    }
    return (res, newOffset)
}

func beVariableByteInteger(length: Int) -> [UInt8] {
    var res = [UInt8]()
    var tmpLen: Int = length
    repeat {
        var d = UInt8(tmpLen % 128)
        tmpLen /= 128
        if tmpLen > 0 {
            d |= 0x80
        }
        res.append(d)
    } while(tmpLen > 0)

    return res
}
