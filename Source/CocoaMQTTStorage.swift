//
//  CocoaMQTTStorage.swift
//  CocoaMQTT
//
//  Created by JianBo on 2019/10/6.
//  Copyright © 2019 emqtt.io. All rights reserved.
//

import Foundation

protocol CocoaMQTTStorageProtocol {
    var clientId: String { get set }

    init?(by clientId: String)

    func write(_ frame: FramePublish) -> Bool

    func write(_ frame: FramePubRel) -> Bool

    func remove(_ frame: FramePublish)

    func remove(_ frame: FramePubRel)

    func synchronize() -> Bool

    /// Read all stored messages by saving order
    func readAll() -> [Frame]
}

final class CocoaMQTTStorage: CocoaMQTTStorageProtocol {
    var clientId: String = ""

    var userDefault = UserDefaults()

    var versionDefault = UserDefaults()

    init?() {
        versionDefault = UserDefaults()
    }

    init?(by clientId: String) {
        guard let userDefault = UserDefaults(suiteName: CocoaMQTTStorage.name(clientId)) else {
            return nil
        }

        self.clientId = clientId
        self.userDefault = userDefault
    }

    deinit {
        userDefault.synchronize()
        versionDefault.synchronize()
    }

    func setMQTTVersion(_ version: String) {
        versionDefault.set(version, forKey: "cocoamqtt.emqx.version")
    }

    func queryMQTTVersion() -> String {
        return versionDefault.string(forKey: "cocoamqtt.emqx.version") ?? "3.1.1"
    }

    func write(_ frame: FramePublish) -> Bool {
        guard frame.qos > .qos0 else {
            return false
        }
        userDefault.set(frame.bytes(version: queryMQTTVersion()), forKey: key(frame.msgid))
        return true
    }

    func write(_ frame: FramePubRel) -> Bool {
        userDefault.set(frame.bytes( version: queryMQTTVersion()), forKey: key(frame.msgid))
        return true
    }

    func remove(_ frame: FramePublish) {
        userDefault.removeObject(forKey: key(frame.msgid))
    }

    func remove(_ frame: FramePubRel) {
        userDefault.removeObject(forKey: key(frame.msgid))
    }

    func remove(_ frame: Frame) {
        if let pub = frame as? FramePublish {
            userDefault.removeObject(forKey: key(pub.msgid))
        } else if let rel = frame as? FramePubRel {
            userDefault.removeObject(forKey: key(rel.msgid))
        }
    }

    func synchronize() -> Bool {
        return userDefault.synchronize()
    }

    func readAll() -> [Frame] {
        return read(needDelete: false)
    }

    func takeAll() -> [Frame] {
        return read(needDelete: true)
    }

    private func key(_ msgid: UInt16) -> String {
        return "\(msgid)"
    }

    private class func name(_ clientId: String) -> String {
        return "cocomqtt-\(clientId)"
    }

    private func parse(_ bytes: [UInt8]) -> (UInt8, [UInt8])? {
        // FramePubRel is 4 bytes long
        guard bytes.count > 3 else {
            return nil
        }
        /// bytes 1..<5 may be 'Remaining Length'
        for i in 1 ..< min(5, bytes.count) where (bytes[i] & 0x80) == 0 {
            return (bytes[0], Array(bytes.suffix(from: i + 1)))
        }

        return nil
    }

    private func read(needDelete: Bool) -> [Frame] {
        var frames = [Frame]()
        let allObjs = userDefault.dictionaryRepresentation().sorted { k1, k2 in
            return k1.key < k2.key
        }
        for (k, v) in allObjs {
            guard let bytes = v as? [UInt8] else { continue }
            guard let parsed = parse(bytes) else { continue }

            if needDelete {
                userDefault.removeObject(forKey: k)
            }

            if let f = FramePublish(packetFixedHeaderType: parsed.0, bytes: parsed.1) {
                frames.append(f)
            } else if let f = FramePubRel(packetFixedHeaderType: parsed.0, bytes: parsed.1) {
                frames.append(f)
            }
        }
        return frames
    }
}
