//
//  CocoaMQTTTests.swift
//  CocoaMQTTTests
//
//  Created by CrazyWisdom on 15/12/11.
//  Copyright © 2015年 emqx.io. All rights reserved.
//

@testable import CocoaMQTT
import XCTest
#if IS_SWIFT_PACKAGE
@testable import CocoaMQTTWebSocket
#endif

private let host = "localhost"
private let port: UInt16 = 1883
private let sslport: UInt16 = 8883
private let clientID = "ClientForUnitTesting-" + randomCode(length: 6)

private let delegateQueueKey = DispatchSpecificKey<String>()
private let delegateQueueVal = "_custom_delegate_queue_"

class CocoaMQTTTests: XCTestCase {
    var deleQueue: DispatchQueue!

    override func setUp() {
        deleQueue = DispatchQueue(label: "cttest")
        deleQueue.setSpecific(key: delegateQueueKey, value: delegateQueueVal)
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testConnect() {
        let caller = Caller()
        let mqtt = CocoaMQTT(clientID: clientID, host: host, port: port)
        mqtt.delegateQueue = deleQueue
        mqtt.delegate = caller
        mqtt.logLevel = .error
        mqtt.autoReconnect = false

        _ = mqtt.connect()
        wait_for { caller.isConnected }
        XCTAssertEqual(mqtt.connState, .connected)

        let topics = ["t/0", "t/1", "t/2"]

        mqtt.subscribe(topics[0])
        mqtt.subscribe(topics[1])
        mqtt.subscribe(topics[2])
        wait_for {
            caller.subs == topics
        }

        mqtt.publish(topics[0], withString: "0", qos: .qos0, retained: false)
        mqtt.publish(topics[1], withString: "1", qos: .qos1, retained: false)
        mqtt.publish(topics[2], withString: "2", qos: .qos2, retained: false)
        wait_for {
            if caller.recvs.count >= 3 {
                let f0 = caller.recvs[0]
                let f1 = caller.recvs[1]
                let f2 = caller.recvs[2]
                XCTAssertEqual(f0.topic, topics[0])
                XCTAssertEqual(f1.topic, topics[1])
                XCTAssertEqual(f2.topic, topics[2])
                return true
            }
            return false
        }

        mqtt.unsubscribe(topics[0])
        mqtt.unsubscribe(topics[1])
        mqtt.unsubscribe(topics[2])
        wait_for {
            caller.subs == []
        }

        mqtt.disconnect()
        wait_for {
            caller.isConnected == false
        }
        XCTAssertEqual(mqtt.connState, .disconnected)
    }

    // This is a basic test of the websocket authentication used by AWS IoT Custom Authorizers
    // https://docs.aws.amazon.com/iot/latest/developerguide/custom-authorizer.html
    func testWebsocketAuthConnect() {
        return // Fix to have the test pass in case the AWS IoT endpoint has not been setup
        let caller = Caller()
        let websocket = CocoaMQTTWebSocket(uri: "/mqtt")
        websocket.headers = [
            "x-amz-customauthorizer-name": "tokenAuthorizer",
            // swiftlint:disable:next line_length
            "x-amz-customauthorizer-signature": "qnQ+T1i2ahSuispDMbjBPn/bN91jDpOmiRAVfTqfXTVvrEP6mNroYJLeVm6vrCp0dODgoiNYKWjwXANuseVafMALL18rMVyQOCaRTStI7xh/pFKVtnK+pdJroPto8ElJhia4cfETwmCdHq7rXLUqdvUGFiVh4+67M5R6088bfhZnjwjgcvhvG8mpTo2yONOkqDK9eA9XZcJhjrURF8DHsPrpIjIihYHq7LdsL5nFJ9FM11mA2AUj51fHZHO7uOfegprFgIeI32Tcn5KEWEDGrD3shvOrqUtDuodrfkALGtNjpGdWNOp/8XKK19KsbUJJrMaH6CDk3j6pn7S1lilz2Q==",
            "token": "3c7a880d-0868-40dc-8183-8870323803fa",
            "Sec-WebSocket-Protocol": "mqttv3.1"
        ]
        websocket.enableSSL = true
        let mqtt = CocoaMQTT(clientID: clientID, host: "XXXXXXXXXXXX-ats.iot.eu-west-1.amazonaws.com", port: 443, socket: websocket)
        mqtt.delegateQueue = deleQueue
        mqtt.delegate = caller
        mqtt.logLevel = .error
        mqtt.autoReconnect = false
        _ = mqtt.connect()
        wait_for { caller.isConnected }
        XCTAssertEqual(mqtt.connState, .connected)
        let topic = "d/AADDS"
        mqtt.subscribe(topic)
        wait_for {
            if caller.subs.count >= 1 {
                if caller.subs[0] == topic {
                    return true
                }
            }
            return false
        }
        mqtt.publish(topic, withString: "0", qos: .qos0, retained: false)
        wait_for {
            if caller.recvs.count >= 1 {
                let f = caller.recvs[0]
                XCTAssertEqual(f.topic, topic)
                return true
            }
            return false
        }
    }

    func testWebsocketConnect() {
        let caller = Caller()
        let websocket = CocoaMQTTWebSocket(uri: "/mqtt")
        let mqtt = CocoaMQTT(clientID: clientID, host: host, port: 8083, socket: websocket)
        mqtt.delegateQueue = deleQueue
        mqtt.delegate = caller
        mqtt.logLevel = .error
        mqtt.autoReconnect = false
        // mqtt.enableSSL = true

        _ = mqtt.connect()
        wait_for { caller.isConnected }
        XCTAssertEqual(mqtt.connState, .connected)

        let topics = ["t/0", "t/1", "t/2"]

        mqtt.subscribe(topics[0])
        mqtt.subscribe(topics[1])
        mqtt.subscribe(topics[2])
        wait_for {
            caller.subs == topics
        }

        mqtt.publish(topics[0], withString: "0", qos: .qos0, retained: false)
        mqtt.publish(topics[1], withString: "1", qos: .qos1, retained: false)
        mqtt.publish(topics[2], withString: "2", qos: .qos2, retained: false)
        wait_for {
            if caller.recvs.count >= 3 {
                let f0 = caller.recvs[0]
                let f1 = caller.recvs[1]
                let f2 = caller.recvs[2]
                XCTAssertEqual(f0.topic, topics[0])
                XCTAssertEqual(f1.topic, topics[1])
                XCTAssertEqual(f2.topic, topics[2])
                return true
            }
            return false
        }

        mqtt.unsubscribe(topics[0])
        mqtt.unsubscribe(topics[1])
        mqtt.unsubscribe(topics[2])
        wait_for {
            caller.subs == []
        }

        mqtt.disconnect()
        wait_for {
            caller.isConnected == false
        }
        XCTAssertEqual(mqtt.connState, .disconnected)
   }

    func testAutoReconnect() {
        let caller = Caller()
        let mqtt = CocoaMQTT(clientID: clientID, host: host, port: port)
        mqtt.delegateQueue = deleQueue
        mqtt.delegate = caller
        mqtt.logLevel = .error
        mqtt.autoReconnect = true
        mqtt.autoReconnectTimeInterval = 1

        _ = mqtt.connect()
        wait_for { caller.isConnected }
        XCTAssertEqual(mqtt.connState, .connected)

        mqtt.internal_disconnect()
        wait_for {
            caller.isConnected == false
        }

        // Waiting for auto-reconnect
        wait_for { caller.isConnected }

        mqtt.disconnect()
        wait_for {
            caller.isConnected == false
        }
        XCTAssertEqual(mqtt.connState, .disconnected)
    }

    func testLongString() {
        let caller = Caller()
        let mqtt = CocoaMQTT(clientID: clientID, host: host, port: port)
        mqtt.delegateQueue = deleQueue
        mqtt.delegate = caller
        mqtt.logLevel = .error
        mqtt.autoReconnect = false

        _ = mqtt.connect()
        wait_for { caller.isConnected }
        XCTAssertEqual(mqtt.connState, .connected)

        mqtt.subscribe("t/#", qos: .qos2)
        wait_for {
            caller.subs == ["t/#"]
        }

        mqtt.publish("t/1", withString: longStringGen(), qos: .qos2)
        wait_for {
            guard !caller.recvs.isEmpty else {
                return false
            }
            XCTAssertEqual(caller.recvs[0].topic, "t/1")
            return true
        }

        mqtt.disconnect()
        wait_for { caller.isConnected == false }
        XCTAssertEqual(mqtt.connState, .disconnected)
    }

    func testProcessSafePub() {
        let caller = Caller()
        let mqtt = CocoaMQTT(clientID: clientID, host: host, port: port)
        mqtt.delegateQueue = deleQueue
        mqtt.delegate = caller
        mqtt.logLevel = .error
        mqtt.autoReconnect = false

        _ = mqtt.connect()
        wait_for { caller.isConnected }
        XCTAssertEqual(mqtt.connState, .connected)

        mqtt.subscribe("t/#", qos: .qos1)
        wait_for {
            caller.subs == ["t/#"]
        }

        mqtt.inflightWindowSize = 10
        mqtt.messageQueueSize = 100

        let concurrentQueue = DispatchQueue(label: "tests.cocoamqtt.emqx", qos: .default, attributes: .concurrent)
        for i in 0 ..< 100 {
            concurrentQueue.async {
                mqtt.publish("t/\(i)", withString: "m\(i)", qos: .qos1)
            }
        }
        wait_for {
            caller.recvs.count == 100
        }

        mqtt.disconnect()
        wait_for { caller.isConnected == false }
        XCTAssertEqual(mqtt.connState, .disconnected)
    }

    func testOnyWaySSL() {
        let caller = Caller()
        let mqtt = CocoaMQTT(clientID: clientID, host: host, port: sslport)
        mqtt.delegateQueue = deleQueue
        mqtt.delegate = caller
        mqtt.logLevel = .error
        mqtt.enableSSL = true
        mqtt.allowUntrustCACertificate = true

        _ = mqtt.connect()
        wait_for { caller.isConnected }
        XCTAssertTrue(caller.isSSL)
        XCTAssertEqual(mqtt.connState, .connected)

        mqtt.disconnect()
        wait_for { caller.isConnected == false }
        XCTAssertEqual(mqtt.connState, .disconnected)
    }

    func testTwoWaySLL() {
        let caller = Caller()
        let mqtt = CocoaMQTT(clientID: clientID, host: host, port: sslport)
        mqtt.delegateQueue = deleQueue
        mqtt.delegate = caller
        mqtt.logLevel = .error
        mqtt.enableSSL = true
        mqtt.allowUntrustCACertificate = true

        let clientCertArray = getClientCertFromP12File(certName: "client-keycert", certPassword: "MySecretPassword")

        var sslSettings: [String: NSObject] = [:]
        sslSettings[kCFStreamSSLCertificates as String] = clientCertArray

        mqtt.sslSettings = sslSettings

        _ = mqtt.connect()
        wait_for { caller.isConnected }
        XCTAssertTrue(caller.isSSL)
        XCTAssertEqual(mqtt.connState, .connected)

        mqtt.disconnect()
        wait_for { caller.isConnected == false }
        XCTAssertEqual(mqtt.connState, .disconnected)
    }
}

extension CocoaMQTTTests {
    func wait_for(line: Int = #line, t: Int = 10, _ fun: @escaping () -> Bool) {
        let exp = XCTestExpectation(description: "line: \(line)")
        let thrd = Thread {
            while true {
                usleep(useconds_t(1000))
                guard fun() else {
                    continue
                }
                exp.fulfill()
                break
            }
        }
        thrd.start()
        wait(for: [exp], timeout: TimeInterval(t))
        thrd.cancel()
    }

    private func ms_sleep(_ ms: Int) {
        usleep(useconds_t(ms * 1000))
    }

    func getClientCertFromP12File(certName: String, certPassword: String) -> CFArray? {
        let testBundle = Bundle(for: type(of: self))

        // get p12 file path
        let resourcePath = testBundle.path(forResource: certName, ofType: "p12")

        guard let filePath = resourcePath, let p12Data = NSData(contentsOfFile: filePath) else {
            print("Failed to open the certificate file: \(certName).p12")
            return nil
        }

        // create key dictionary for reading p12 file
        let key = kSecImportExportPassphrase as String
        let options: NSDictionary = [key: certPassword]

        var items: CFArray?
        let securityError = SecPKCS12Import(p12Data, options, &items)

        guard securityError == errSecSuccess else {
            if securityError == errSecAuthFailed {
                print("ERROR: SecPKCS12Import returned errSecAuthFailed. Incorrect password?")
            } else {
                print("Failed to open the certificate file: \(certName).p12")
            }
            return nil
        }

        guard let theArray = items, CFArrayGetCount(theArray) > 0 else {
            return nil
        }

        let dictionary = (theArray as NSArray).object(at: 0)
        guard let identity = (dictionary as AnyObject).value(forKey: kSecImportItemIdentity as String) else {
            return nil
        }
        let certArray = [identity] as CFArray

        return certArray
    }
}

private class Caller: CocoaMQTTDelegate {
    var recvs = [FramePublish]()

    var sents = [UInt16]()

    var acks = [UInt16]()

    var subs = [String]()

    var isConnected = false

    var isSSL = false

    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        assert_in_del_queue()
        if ack == .accept { isConnected = true }
    }

    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        assert_in_del_queue()

        sents.append(id)
    }

    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        assert_in_del_queue()

        acks.append(id)
    }

    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        assert_in_del_queue()

        var frame = message.tPubFrame
        frame.msgid = id
        recvs.append(frame)
    }

    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        assert_in_del_queue()

        subs += (success.allKeys as! [String])
    }

    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {
        assert_in_del_queue()

        subs = subs.filter { e -> Bool in
            !topics.contains(e)
        }
    }

    func mqttDidPing(_ mqtt: CocoaMQTT) {
        assert_in_del_queue()
    }

    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        assert_in_del_queue()
    }

    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        assert_in_del_queue()

        isConnected = false
    }

    func mqtt(_ mqtt: CocoaMQTT, didStateChangeTo state: CocoaMQTTConnState) {
        assert_in_del_queue()
    }

    func mqtt(_ mqtt: CocoaMQTT, didPublishComplete id: UInt16) {
        assert_in_del_queue()
    }

    func mqtt(_ mqtt: CocoaMQTT, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        assert_in_del_queue()

        isSSL = true

        completionHandler(true)
    }

    func assert_in_del_queue() {
        XCTAssertEqual(delegateQueueVal, DispatchQueue.getSpecific(key: delegateQueueKey))
    }
}

// tools
private func randomCode(length: Int) -> String {
    let base62chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    var code = ""
    for _ in 0..<length {
        let random = Int.random(in: 0...62)
        let index = base62chars.index(base62chars.startIndex, offsetBy: random)
        code.append(base62chars[index])
    }
    return code
}

private func longStringGen() -> String {
    var string = ""
    let shijing = "燕燕于飞，差池其羽。之子于归，远送于野。瞻望弗及，泣涕如雨。\n" +
                  "燕燕于飞，颉之颃之。之子于归，远于将之。瞻望弗及，伫立以泣。\n" +
                  "燕燕于飞，下上其音。之子于归，远送于南。瞻望弗及，实劳我心。\n" +
                  "仲氏任只，其心塞渊。终温且惠，淑慎其身。先君之思，以勗寡人。\n"

    for _ in 1...100 {
        string.append(shijing)
    }
    return string
}
