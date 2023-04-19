//
//  CocoaMQTTReader.swift
//  CocoaMQTT
//
//  Created by HJianBo on 2019/5/21.
//  Copyright © 2019 emqx.io. All rights reserved.
//

import Foundation

/// Read tag for AsyncSocket
enum CocoaMQTTReadTag: Int {
    case header = 0
    case length
    case payload
}

///
protocol CocoaMQTTReaderDelegate: AnyObject {
    func didReceive(_ reader: CocoaMQTTReader, connack: FrameConnAck)

    func didReceive(_ reader: CocoaMQTTReader, publish: FramePublish)

    func didReceive(_ reader: CocoaMQTTReader, puback: FramePubAck)

    func didReceive(_ reader: CocoaMQTTReader, pubrec: FramePubRec)

    func didReceive(_ reader: CocoaMQTTReader, pubrel: FramePubRel)

    func didReceive(_ reader: CocoaMQTTReader, pubcomp: FramePubComp)

    func didReceive(_ reader: CocoaMQTTReader, suback: FrameSubAck)

    func didReceive(_ reader: CocoaMQTTReader, unsuback: FrameUnsubAck)

    func didReceive(_ reader: CocoaMQTTReader, pingresp: FramePingResp)
}

class CocoaMQTTReader {
    private var socket: CocoaMQTTSocketProtocol

    private weak var delegate: CocoaMQTTReaderDelegate?

    private let timeout: TimeInterval = 30_000

    /*  -- Reader states -- */
    private var header: UInt8 = 0
    private var length: UInt = 0
    private var data: [UInt8] = []
    private var multiply = 1
    /*  -- Reader states -- */

    init(socket: CocoaMQTTSocketProtocol, delegate: CocoaMQTTReaderDelegate?) {
        self.socket = socket
        self.delegate = delegate
    }

    func start() {
        readHeader()
    }

    func headerReady(_ header: UInt8) {
        self.header = header
        readLength()
    }

    func lengthReady(_ byte: UInt8) {
        length += (UInt)((Int)(byte & 127) * multiply)
        // done
        if byte & 0x80 == 0 {
            if length == 0 {
                frameReady()
            } else {
                readPayload()
            }
            // more
        } else {
            let result = multiply.multipliedReportingOverflow(by: 128)
            if !result.overflow {
                multiply = result.partialValue
            } else {
                reset()
            }
            readLength()
        }
    }

    func payloadReady(_ data: Data) {
        self.data = [UInt8](repeating: 0, count: data.count)
        data.copyBytes(to: &(self.data), count: data.count)
        frameReady()
    }

    private func readHeader() {
        reset()
        socket.readData(toLength: 1, withTimeout: -1, tag: CocoaMQTTReadTag.header.rawValue)
    }

    private func readLength() {
        socket.readData(toLength: 1, withTimeout: timeout, tag: CocoaMQTTReadTag.length.rawValue)
    }

    private func readPayload() {
        socket.readData(toLength: length, withTimeout: timeout, tag: CocoaMQTTReadTag.payload.rawValue)
    }

    private func frameReady() {
        guard let frameType = FrameType(rawValue: UInt8(header & 0xF0)) else {
            printError("Received unknown frame type, header: \(header), data:\(data)")
            readHeader()
            return
        }

        // XXX: stupid implement

        switch frameType {
        case .connack:
            guard let connack = FrameConnAck(packetFixedHeaderType: header, bytes: data) else {
                printError("Reader parse \(frameType) failed, data: \(data)")
                break
            }
            delegate?.didReceive(self, connack: connack)
        case .publish:
            guard let publish = FramePublish(packetFixedHeaderType: header, bytes: data) else {
                printError("Reader parse \(frameType) failed, data: \(data)")
                break
            }
            delegate?.didReceive(self, publish: publish)
        case .puback:
            guard let puback = FramePubAck(packetFixedHeaderType: header, bytes: data) else {
                printError("Reader parse \(frameType) failed, data: \(data)")
                break
            }
            delegate?.didReceive(self, puback: puback)
        case .pubrec:
            guard let pubrec = FramePubRec(packetFixedHeaderType: header, bytes: data) else {
                printError("Reader parse \(frameType) failed, data: \(data)")
                break
            }
            delegate?.didReceive(self, pubrec: pubrec)
        case .pubrel:
            guard let pubrel = FramePubRel(packetFixedHeaderType: header, bytes: data) else {
                printError("Reader parse \(frameType) failed, data: \(data)")
                break
            }
            delegate?.didReceive(self, pubrel: pubrel)
        case .pubcomp:
            guard let pubcomp = FramePubComp(packetFixedHeaderType: header, bytes: data) else {
                printError("Reader parse \(frameType) failed, data: \(data)")
                break
            }
            delegate?.didReceive(self, pubcomp: pubcomp)
        case .suback:
            guard let frame = FrameSubAck(packetFixedHeaderType: header, bytes: data) else {
                printError("Reader parse \(frameType) failed, data: \(data)")
                break
            }
            delegate?.didReceive(self, suback: frame)
        case .unsuback:
            guard let frame = FrameUnsubAck(packetFixedHeaderType: header, bytes: data) else {
                printError("Reader parse \(frameType) failed, data: \(data)")
                break
            }
            delegate?.didReceive(self, unsuback: frame)
        case .pingresp:
            guard let frame = FramePingResp(packetFixedHeaderType: header, bytes: data) else {
                printError("Reader parse \(frameType) failed, data: \(data)")
                break
            }
            delegate?.didReceive(self, pingresp: frame)
        default:
            break
        }

        readHeader()
    }

    private func reset() {
        length = 0
        multiply = 1
        header = 0
        data = []
    }
}
