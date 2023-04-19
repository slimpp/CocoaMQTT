//
//  CocoaMQTTStorageTests.swift
//  CocoaMQTT-Tests
//
//  Created by JianBo on 2019/10/6.
//  Copyright © 2019 emqtt.io. All rights reserved.
//

@testable import CocoaMQTT
import XCTest

class CocoaMQTTStorageTests: XCTestCase {
    var clientId = "c1"

    func testStorage() {
        let frames = [FramePublish(topic: "t/1", payload: [0x01], qos: .qos1, msgid: 1),
                      FramePublish(topic: "t/2", payload: [0x01], qos: .qos1, msgid: 2),
                      FramePublish(topic: "t/3", payload: [0x01], qos: .qos1, msgid: 3) ]

        var storage: CocoaMQTTStorage? = CocoaMQTTStorage(by: clientId)

        for f in frames {
            XCTAssertEqual(true, storage?.write(f))
        }

        storage?.remove(frames[1])
        storage = nil

        storage = CocoaMQTTStorage(by: clientId)
        let should = [frames[0], frames[2]]
        let saved = storage?.readAll()
        XCTAssertEqual(should.count, saved?.count)
        for i in 0 ..< should.count {
            assertEqual(should[i], saved?[i])
        }

        let taken = storage?.takeAll()
        XCTAssertEqual(should.count, taken?.count)
        for i in 0 ..< should.count {
            assertEqual(should[i], taken?[i])
        }

        XCTAssertEqual(storage?.readAll().count, 0)
    }

    private func assertEqual(_ f1: Frame?, _ f2: Frame?) {
        if let pub1 = f1 as? FramePublish,
            let pub2 = f2 as? FramePublish {
            XCTAssertEqual(pub1.topic, pub2.topic)
            XCTAssertEqual(pub1.payload(), pub2.payload())
            XCTAssertEqual(pub1.msgid, pub2.msgid)
            XCTAssertEqual(pub1.qos, pub2.qos)
        } else if let rel1 = f1 as? FramePubRel,
            let rel2 = f2 as? FramePubRel {
            XCTAssertEqual(rel1.msgid, rel2.msgid)
        } else {
            XCTAssert(false)
        }
    }
}
