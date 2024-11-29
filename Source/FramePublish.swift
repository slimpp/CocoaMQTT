//
//  FramePublish.swift
//  CocoaMQTT
//
//  Created by JianBo on 2019/8/7.
//  Copyright © 2019 emqx.io. All rights reserved.
//

import Foundation

// MQTT PUBLISH Frame
struct FramePublish: Frame {

    //3.3.1.4 Remaining Length
    public var remainingLength: UInt32?

    //3.3.2.1 Topic Name
    public var topicName: String?
    //3.3.2.2 Packet Identifier
    public var packetIdentifier: UInt16?

    //3.3.2.3 PUBLISH Properties
    public var publishProperties: MqttPublishProperties?
    public var publishRecProperties: MqttDecodePublish?

    var packetFixedHeaderType: UInt8 = FrameType.publish.rawValue
    
    // --- Attributes
    
    var msgid: UInt16
    
    var topic: String = "";
    
    var _payload: [UInt8] = []

    var mqtt5Topic: String = "";


    // --- Attributes End
    
    init(topic: String, payload: [UInt8], qos: CocoaMQTTQoS = .qos0, msgid: UInt16 = 0){
        
        self.topic = topic
        self._payload = payload
        self.msgid = msgid
        self.qos = qos
    }
}

extension FramePublish {
    
    func fixedHeader() -> [UInt8] {
        
        var header = [UInt8]()
        header += [FrameType.publish.rawValue]

        return header
    }
    
    func variableHeader5() -> [UInt8] {

        //3.3.2.1 Topic Name
        var header = self.topic.bytesWithLength
        //3.3.2.2 Packet Identifier qos1 or qos2
        if qos > .qos0 {
            header += msgid.hlBytes
            //            header.append(UInt8(0))
            //            header.append(QoS.rawValue)
        }

        //MQTT 5.0
        header += beVariableByteInteger(length: self.properties().count)


        return header
    }
    
    func payload5() -> [UInt8] { return _payload }

    func properties() -> [UInt8] {
        
        // Properties
        return publishProperties?.properties ?? []
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

        var header = topic.bytesWithLength

        if qos > .qos0 {
            header += msgid.hlBytes
        }

        return header
    }

    func payload() -> [UInt8] { return _payload }
}

extension FramePublish: InitialWithBytes {
    
    init?(packetFixedHeaderType: UInt8, bytes: [UInt8]) {
        
        guard packetFixedHeaderType & 0xF0 == FrameType.publish.rawValue else {
            return nil
        }
        let recDup = ((packetFixedHeaderType & 0b0000_1000) >> 3) > 0

        guard let recQos = CocoaMQTTQoS(rawValue: (packetFixedHeaderType & 0b0000_0110) >> 1) else {
            return nil
        }

        let recRetain = (packetFixedHeaderType & 0b0000_0001) > 0
        // Reserved
        var flags: UInt8 = 0

        if recRetain {
            flags = flags | 0b0000_0001
        } else {
            flags = flags | 0b0000_0000
        }

        if recDup {
            flags = flags | 0b0011_1000
        } else {
            flags = flags | 0b0011_0000
        }

        switch recQos {
        case .qos0:
            flags = flags | 0b0011_0000
        case .qos1:
            flags = flags | 0b0011_0010
        case .qos2:
            flags = flags | 0b0011_0100
        case .FAILURE:
            printDebug("FAILTURE")
        }
        self.packetFixedHeaderType = flags

        /// Packet Identifier
        /// The Packet Identifier field is only present in PUBLISH packets where the QoS level is 1 or 2.

        // parse topic
        if bytes.count < 2 {
            return nil
        }

        let len = UInt16(bytes[0]) << 8 + UInt16(bytes[1])

        //2 is packetFixedHeaderType length
        var pos = 2 + Int(len)

        if bytes.count < pos {
            return nil
        }

        // msgid
        if (packetFixedHeaderType & 0x06) >> 1 == CocoaMQTTQoS.qos0.rawValue {
            msgid = 0
        } else {
            if bytes.count < pos + 2 {
                return nil
            }
            msgid = UInt16(bytes[pos]) << 8 + UInt16(bytes[pos+1])
            pos += 2
        }


        var protocolVersion = "";
        if let storage = CocoaMQTTStorage() {
            protocolVersion = storage.queryMQTTVersion()
        }

        if (protocolVersion == "5.0"){
            let data = MqttDecodePublish()
            data.decodePublish(fixedHeader: packetFixedHeaderType ,publishData: bytes)
            pos = data.mqtt5DataIndex

            if(data.propertyLength != 0){
                pos += data.propertyLength!
            }

            // MQTT 5.0
            self.mqtt5Topic = data.topic
            self.packetIdentifier = data.packetIdentifier
            self.publishRecProperties = data

        }else{
            // MQTT 3.1.1
            if let data = NSString(bytes: [UInt8](bytes[2...(pos-1)]), length: Int(len), encoding: String.Encoding.utf8.rawValue) {
                topic =  data as String
            }
        }

        // payload
        if (pos == bytes.count) {
            _payload = []
        } else if (pos < bytes.count) {
            _payload = [UInt8](bytes[pos..<bytes.count])
        } else {
            return nil
        }

    }
}

extension FramePublish: CustomStringConvertible {
    var description: String {
        return "PUBLISH(id: \(msgid), topic: \(topic), payload: \(_payload.summary))"
    }
}
