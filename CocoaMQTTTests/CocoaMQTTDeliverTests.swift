//
//  CocoaMQTTDeliverTests.swift
//  CocoaMQTT-Tests
//
//  Created by JianBo on 2019/10/3.
//  Copyright © 2019 emqtt.io. All rights reserved.
//

@testable import CocoaMQTT
import XCTest

class CocoaMQTTDeliverTests: XCTestCase {
    func testSerialDeliver() {
        let caller = Caller()
        let deliver = CocoaMQTTDeliver()

        let frames = [FramePublish(topic: "t/0", payload: [0x00], qos: .qos0),
                      FramePublish(topic: "t/1", payload: [0x01], qos: .qos1, msgid: 1),
                      FramePublish(topic: "t/2", payload: [0x02], qos: .qos2, msgid: 2)]

        deliver.delegate = caller
        for f in frames {
            _ = deliver.add(f)
        }
        ms_sleep(100)

        XCTAssertEqual(frames.count, caller.frames.count)
        for i in 0 ..< frames.count {
            assertEqual(frames[i], caller.frames[i])
        }
    }

    func testAckMessage() {
        let caller = Caller()
        let deliver = CocoaMQTTDeliver()

        let frames = [FramePublish(topic: "t/0", payload: [0x00], qos: .qos0),
                      FramePublish(topic: "t/1", payload: [0x01], qos: .qos1, msgid: 1),
                      FramePublish(topic: "t/2", payload: [0x02], qos: .qos2, msgid: 2)]

        deliver.delegate = caller
        for f in frames {
            _ = deliver.add(f)
        }

        ms_sleep(100)

        XCTAssertEqual(frames.count, caller.frames.count)
        for i in 0 ..< frames.count {
            assertEqual(frames[i], caller.frames[i])
        }

        var inflights = deliver.t_inflightFrames()
        XCTAssertEqual(inflights.count, 2)
        XCTAssertEqual(deliver.t_queuedFrames().count, 0)
        for i in 0 ..< inflights.count {
            assertEqual(inflights[i], frames[i + 1])
        }

        deliver.ack(by: FramePubAck(msgid: 1))
        deliver.ack(by: FramePubRec(msgid: 2))
        ms_sleep(100)

        inflights = deliver.t_inflightFrames()
        XCTAssertEqual(inflights.count, 1)
        XCTAssertEqual(deliver.t_queuedFrames().count, 0)
        assertEqual(inflights[0], FramePubRel(msgid: 2))

        deliver.ack(by: FramePubComp(msgid: 2))
        ms_sleep(100)

        inflights = deliver.t_inflightFrames()
        XCTAssertEqual(inflights.count, 0)

        // Assert sent
        assertEqual(caller.frames[3], FramePubRel(msgid: 2))
    }

    func testQueueAndInflightReDeliver() {
        let caller = Caller()
        let deliver = CocoaMQTTDeliver()

        let frames = [FramePublish(topic: "t/0", payload: [0x00], qos: .qos0),
                      FramePublish(topic: "t/1", payload: [0x01], qos: .qos1, msgid: 1),
                      FramePublish(topic: "t/2", payload: [0x02], qos: .qos2, msgid: 2)]

        deliver.retryTimeInterval = 1000
        deliver.inflightWindowSize = 1
        deliver.mqueueSize = 1
        deliver.delegate = caller

        XCTAssertTrue(deliver.add(frames[1]))
        ms_sleep(100) // Wait the message transfer to inflight-window
        XCTAssertTrue(deliver.add(frames[2]))
        XCTAssertFalse(deliver.add(frames[0]))

        ms_sleep(1100) // Wait for re-delivering timeout
        XCTAssertEqual(caller.frames.count, 2)
        assertEqual(caller.frames[0], frames[1])
        assertEqual(caller.frames[1], frames[1])

        deliver.ack(by: FramePubAck(msgid: 1))
        ms_sleep(100)   // Waiting for the frame in the mqueue transfer to inflight window

        var inflights = deliver.t_inflightFrames()
        XCTAssertEqual(inflights.count, 1)
        assertEqual(inflights[0], frames[2])

        deliver.ack(by: FramePubRec(msgid: 2))
        ms_sleep(2000)  // Waiting for re-delivering timeout
        deliver.ack(by: FramePubComp(msgid: 2))
        ms_sleep(100)

        inflights = deliver.t_inflightFrames()
        XCTAssertEqual(inflights.count, 0)

        let sents: [Frame] = [frames[1], frames[1], frames[2], FramePubRel(msgid: 2), FramePubRel(msgid: 2)]
        XCTAssertEqual(caller.frames.count, sents.count)
        for i in 0 ..< sents.count {
            assertEqual(caller.frames[i], sents[i])
        }
    }

    func testStorage() {
        let clientID = "deliver-unit-testing"
        let caller = Caller()
        let deliver = CocoaMQTTDeliver()

        let frames = [FramePublish(topic: "t/0", payload: [0x00], qos: .qos0),
                      FramePublish(topic: "t/1", payload: [0x01], qos: .qos1, msgid: 1),
                      FramePublish(topic: "t/2", payload: [0x02], qos: .qos2, msgid: 2)]

        guard let storage = CocoaMQTTStorage(by: clientID) else {
            XCTAssert(false, "Initial storage failed")
            return
        }

        deliver.delegate = caller
        deliver.recoverSessionBy(storage)

        for f in frames {
            _ = deliver.add(f)
        }

        var saved = storage.readAll()
        XCTAssertEqual(saved.count, 2)

        deliver.ack(by: FramePubAck(msgid: 1))
        ms_sleep(100)
        saved = storage.readAll()
        XCTAssertEqual(saved.count, 1)

        deliver.ack(by: FramePubRec(msgid: 2))
        ms_sleep(100)
        saved = storage.readAll()
        XCTAssertEqual(saved.count, 1)
        assertEqual(saved[0], FramePubRel(msgid: 2))

        deliver.ack(by: FramePubComp(msgid: 2))
        ms_sleep(100)
        saved = storage.readAll()
        XCTAssertEqual(saved.count, 0)

        caller.reset()
        _ = storage.write(frames[1])
        deliver.recoverSessionBy(storage)
        ms_sleep(100)
        XCTAssertEqual(caller.frames.count, 1)
        assertEqual(caller.frames[0], frames[1])

        deliver.ack(by: FramePubAck(msgid: 1))
        ms_sleep(100)
        XCTAssertEqual(storage.readAll().count, 0)
    }

    // TODO: How to test large of messages combined qos0/qos1/qos2

    // Helper for assert equality for Frame
    private func assertEqual(_ f1: Frame, _ f2: Frame, _ lines: Int = #line) {
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
            XCTAssert(false, "Assert equal failed line: \(lines)")
        }
    }

    private func ms_sleep(_ ms: Int) {
        usleep(useconds_t(ms * 1000))
    }
}

private class Caller: CocoaMQTTDeliverProtocol {
    private let delegateQueueKey = DispatchSpecificKey<String>()
    private let delegateQueueVal = "_custom_delegate_queue_"

    var delegateQueue: DispatchQueue

    var frames = [Frame]()

    init() {
        delegateQueue = DispatchQueue(label: "caller.deliver.test")
        delegateQueue.setSpecific(key: delegateQueueKey, value: delegateQueueVal)
    }

    func reset() {
        frames = []
    }

    func deliver(_ deliver: CocoaMQTTDeliver, wantToSend frame: Frame) {
        assert_in_del_queue()

        frames.append(frame)
    }

    private func assert_in_del_queue() {
        XCTAssertEqual(delegateQueueVal, DispatchQueue.getSpecific(key: delegateQueueKey))
    }
}
