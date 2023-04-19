//
//  ViewController.swift
//  Example
//
//  Created by CrazyWisdom on 15/12/14.
//  Copyright © 2015年 emqtt.io. All rights reserved.
//

import CocoaMQTT
import UIKit

class ViewController: UIViewController {
    // let defaultHost = "localhost"
    // OR
    // TEST Broker
    let defaultHost = "broker-cn.emqx.io"

    var mqtt5: CocoaMQTT5?
    var mqtt: CocoaMQTT?
    var animal: String?
    var mqttVesion: String?

    @IBOutlet private weak var versionControl: UISegmentedControl!
    @IBOutlet private weak var connectButton: UIButton!
    @IBOutlet private weak var animalsImageView: UIImageView! {
        didSet {
            animalsImageView.clipsToBounds = true
            animalsImageView.layer.borderWidth = 1.0
            animalsImageView.layer.cornerRadius = animalsImageView.frame.width / 2.0
        }
    }

    @IBAction private func connectToServer() {
        if mqttVesion == "3.1.1" {
            _ = mqtt!.connect()
        } else if mqttVesion == "5.0"{
            _ = mqtt5!.connect()
        }
    }

    @IBAction private func mqttVersionControl(_ sender: UISegmentedControl) {
        animal = tabBarController?.selectedViewController?.tabBarItem.title
        mqttVesion = versionControl.titleForSegment(at: versionControl.selectedSegmentIndex)

        mqttSettingList()

        print("welcome to MQTT \(String(describing: mqttVesion))  \(String(describing: animal))")
    }

    func sendAuthToServer() {
        let authProperties = MqttAuthProperties()
        mqtt5!.auth(reasonCode: CocoaMQTTAUTHReasonCode.continueAuthentication, authProperties: authProperties)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        tabBarController?.delegate = self
        animal = tabBarController?.selectedViewController?.tabBarItem.title
        mqttVesion = versionControl.titleForSegment(at: versionControl.selectedSegmentIndex)

        mqttSettingList()

        print("welcome to MQTT \(String(describing: mqttVesion))  \(String(describing: animal))")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = false
    }

    func mqttSettingList() {
        mqttSetting()
        // selfSignedSSLSetting()
        // simpleSSLSetting()
        // mqttWebsocketsSetting()
        // mqttWebsocketSSLSetting()
    }

    func mqttSetting() {
        if mqttVesion == "3.1.1" {
            let clientID = "CocoaMQTT-\(animal!)-" + String(ProcessInfo().processIdentifier)
            mqtt = CocoaMQTT(clientID: clientID, host: defaultHost, port: 1883)
            mqtt!.logLevel = .debug
            mqtt!.username = ""
            mqtt!.password = ""
            mqtt!.willMessage = CocoaMQTTMessage(topic: "/will", string: "dieout")
            mqtt!.keepAlive = 60
            mqtt!.delegate = self
            // mqtt!.autoReconnect = true

        } else if mqttVesion == "5.0" {
            let clientID = "CocoaMQTT5-\(animal!)-" + String(ProcessInfo().processIdentifier)
            mqtt5 = CocoaMQTT5(clientID: clientID, host: defaultHost, port: 1883)
            mqtt5!.logLevel = .debug
            let connectProperties = MqttConnectProperties()
            connectProperties.topicAliasMaximum = 0
            connectProperties.sessionExpiryInterval = 0
            connectProperties.receiveMaximum = 100
            connectProperties.maximumPacketSize = 500

            mqtt5!.connectProperties = connectProperties
            mqtt5!.username = ""
            mqtt5!.password = ""

            let lastWillMessage = CocoaMQTT5Message(topic: "/will", string: "dieout")
            lastWillMessage.contentType = "JSON"
            lastWillMessage.willResponseTopic = "/will"
            lastWillMessage.willExpiryInterval = .max
            lastWillMessage.willDelayInterval = 0
            lastWillMessage.qos = .qos1

            mqtt5!.willMessage = lastWillMessage
            mqtt5!.keepAlive = 60
            mqtt5!.delegate = self
            // mqtt5!.autoReconnect = true

        }
    }

    func simpleSSLSetting() {
        if mqttVesion == "3.1.1" {
            let clientID = "CocoaMQTT-\(animal!)-" + String(ProcessInfo().processIdentifier)
            mqtt = CocoaMQTT(clientID: clientID, host: defaultHost, port: 8883)
            mqtt!.username = ""
            mqtt!.password = ""
            mqtt!.willMessage = CocoaMQTTMessage(topic: "/will", string: "dieout")
            mqtt!.keepAlive = 60
            mqtt!.delegate = self
            mqtt!.enableSSL = true
        } else if mqttVesion == "5.0" {
            let clientID = "CocoaMQTT5-\(animal!)-" + String(ProcessInfo().processIdentifier)
            mqtt5 = CocoaMQTT5(clientID: clientID, host: defaultHost, port: 8883)

            let connectProperties = MqttConnectProperties()
            connectProperties.topicAliasMaximum = 0
            connectProperties.sessionExpiryInterval = 0
            connectProperties.receiveMaximum = 100
            connectProperties.maximumPacketSize = 500

            mqtt5!.connectProperties = connectProperties

            mqtt5!.username = ""
            mqtt5!.password = ""
            mqtt5!.willMessage = CocoaMQTT5Message(topic: "/will", string: "dieout")
            mqtt5!.keepAlive = 60
            mqtt5!.delegate = self

            mqtt5!.enableSSL = true
        }
    }

    func selfSignedSSLSetting() {
        if mqttVesion == "3.1.1" {
            let clientID = "CocoaMQTT-\(animal!)-" + String(ProcessInfo().processIdentifier)
            mqtt = CocoaMQTT(clientID: clientID, host: defaultHost, port: 8883)
            mqtt!.username = ""
            mqtt!.password = ""
            mqtt!.willMessage = CocoaMQTTMessage(topic: "/will", string: "dieout")
            mqtt!.keepAlive = 60
            mqtt!.delegate = self
            mqtt!.enableSSL = true
            mqtt!.allowUntrustCACertificate = true

            let clientCertArray = getClientCertFromP12File(certName: "client-keycert", certPassword: "MySecretPassword")

            var sslSettings: [String: NSObject] = [:]
            sslSettings[kCFStreamSSLCertificates as String] = clientCertArray

            mqtt!.sslSettings = sslSettings
        } else if mqttVesion == "5.0" {
            let clientID = "CocoaMQTT5-\(animal!)-" + String(ProcessInfo().processIdentifier)
            mqtt5 = CocoaMQTT5(clientID: clientID, host: defaultHost, port: 8883)

            let connectProperties = MqttConnectProperties()
            connectProperties.topicAliasMaximum = 0
            connectProperties.sessionExpiryInterval = 0
            connectProperties.receiveMaximum = 100
            connectProperties.maximumPacketSize = 500

            mqtt5!.connectProperties = connectProperties

            mqtt5!.username = ""
            mqtt5!.password = ""
            mqtt5!.willMessage = CocoaMQTT5Message(topic: "/will", string: "dieout")
            mqtt5!.keepAlive = 60
            mqtt5!.delegate = self

            mqtt5!.enableSSL = true
            mqtt5!.allowUntrustCACertificate = true
            let clientCertArray = getClientCertFromP12File(certName: "client-keycert", certPassword: "MySecretPassword")
            var sslSettings: [String: NSObject] = [:]
            sslSettings[kCFStreamSSLCertificates as String] = clientCertArray

            mqtt5!.sslSettings = sslSettings
        }
    }

    func mqttWebsocketsSetting() {
        if mqttVesion == "3.1.1" {
            let clientID = "CocoaMQTT-\(animal!)-" + String(ProcessInfo().processIdentifier)
            let websocket = CocoaMQTTWebSocket(uri: "/mqtt")
            mqtt = CocoaMQTT(clientID: clientID, host: defaultHost, port: 8083, socket: websocket)
            mqtt!.username = ""
            mqtt!.password = ""
            mqtt!.willMessage = CocoaMQTTMessage(topic: "/will", string: "dieout")
            mqtt!.keepAlive = 60
            mqtt!.delegate = self
        } else if mqttVesion == "5.0" {
            let clientID = "CocoaMQTT5-\(animal!)-" + String(ProcessInfo().processIdentifier)
            let websocket = CocoaMQTTWebSocket(uri: "/mqtt")
            mqtt5 = CocoaMQTT5(clientID: clientID, host: defaultHost, port: 8083, socket: websocket)

            let connectProperties = MqttConnectProperties()
            connectProperties.topicAliasMaximum = 0
            connectProperties.sessionExpiryInterval = 0
            connectProperties.receiveMaximum = 100
            connectProperties.maximumPacketSize = 500

            mqtt5!.connectProperties = connectProperties

            mqtt5!.username = ""
            mqtt5!.password = ""

            let lastWillMessage = CocoaMQTT5Message(topic: "/will", string: "dieout")
            lastWillMessage.contentType = "JSON"
            lastWillMessage.willExpiryInterval = .max
            lastWillMessage.willDelayInterval = 0
            lastWillMessage.qos = .qos1

            mqtt5!.willMessage = lastWillMessage
            mqtt5!.keepAlive = 60
            mqtt5!.delegate = self
        }
    }

    func mqttWebsocketSSLSetting() {
        if mqttVesion == "3.1.1" {
            let clientID = "CocoaMQTT-\(animal!)-" + String(ProcessInfo().processIdentifier)
            let websocket = CocoaMQTTWebSocket(uri: "/mqtt")
            mqtt = CocoaMQTT(clientID: clientID, host: defaultHost, port: 8084, socket: websocket)
            mqtt!.enableSSL = true
            mqtt!.username = ""
            mqtt!.password = ""
            mqtt!.willMessage = CocoaMQTTMessage(topic: "/will", string: "dieout")
            mqtt!.keepAlive = 60
            mqtt!.delegate = self
        } else if mqttVesion == "5.0" {
            let clientID = "CocoaMQTT5-\(animal!)-" + String(ProcessInfo().processIdentifier)
            let websocket = CocoaMQTTWebSocket(uri: "/mqtt")
            mqtt5 = CocoaMQTT5(clientID: clientID, host: defaultHost, port: 8084, socket: websocket)

            let connectProperties = MqttConnectProperties()
            connectProperties.topicAliasMaximum = 0
            connectProperties.sessionExpiryInterval = 0
            connectProperties.receiveMaximum = 100
            connectProperties.maximumPacketSize = 500

            mqtt5!.connectProperties = connectProperties

            mqtt5!.enableSSL = true
            mqtt5!.username = ""
            mqtt5!.password = ""
            mqtt5!.willMessage = CocoaMQTT5Message(topic: "/will", string: "dieout")
            mqtt5!.keepAlive = 60
            mqtt5!.delegate = self
        }
    }

    func getClientCertFromP12File(certName: String, certPassword: String) -> CFArray? {
        // get p12 file path
        let resourcePath = Bundle.main.path(forResource: certName, ofType: "p12")

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

extension ViewController: CocoaMQTT5Delegate {
    func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveDisconnectReasonCode reasonCode: CocoaMQTTDISCONNECTReasonCode) {
        print("disconnect res : \(reasonCode)")
    }

    func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveAuthReasonCode reasonCode: CocoaMQTTAUTHReasonCode) {
        print("auth res : \(reasonCode)")
    }

    // Optional ssl CocoaMQTT5Delegate
    func mqtt5(_ mqtt5: CocoaMQTT5, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        TRACE("trust: \(trust)")
        /// Validate the server certificate
        ///
        /// Some custom validation...
        ///
        /// if validatePassed {
        ///     completionHandler(true)
        /// } else {
        ///     completionHandler(false)
        /// }
        completionHandler(true)
    }

    func mqtt5(_ mqtt5: CocoaMQTT5, didConnectAck ack: CocoaMQTTCONNACKReasonCode, connAckData: MqttDecodeConnAck?) {
        TRACE("ack: \(ack)")

        if ack == .success {
            if connAckData != nil {
                print("properties maximumPacketSize: \(String(describing: connAckData!.maximumPacketSize))")
                print("properties topicAliasMaximum: \(String(describing: connAckData!.topicAliasMaximum))")
            }

            mqtt5.subscribe("chat/room/animals/client/+", qos: CocoaMQTTQoS.qos0)
            // or
            // let subscriptions : [MqttSubscription] = [
            //     MqttSubscription(topic: "chat/room/animals/client/+"),
            //     MqttSubscription(topic: "chat/room/foods/client/+"),
            //     MqttSubscription(topic: "chat/room/trees/client/+")
            // ]
            mqtt.subscribe(subscriptions)

            let chatViewController = storyboard?.instantiateViewController(withIdentifier: "ChatViewController") as? ChatViewController
            chatViewController?.mqtt5 = mqtt5
            chatViewController?.mqttVersion = mqttVesion
            navigationController!.pushViewController(chatViewController!, animated: true)
        }
    }

    func mqtt5(_ mqtt5: CocoaMQTT5, didStateChangeTo state: CocoaMQTTConnState) {
        TRACE("new state: \(state)")
        if state == .disconnected {
        }
    }

    func mqtt5(_ mqtt5: CocoaMQTT5, didPublishMessage message: CocoaMQTT5Message, id: UInt16) {
        TRACE("message: \(message.description), id: \(id)")
    }

    func mqtt5(_ mqtt5: CocoaMQTT5, didPublishAck id: UInt16, pubAckData: MqttDecodePubAck?) {
        TRACE("id: \(id)")
        if pubAckData != nil {
            print("pubAckData reasonCode: \(String(describing: pubAckData!.reasonCode))")
        }
    }

    func mqtt5(_ mqtt5: CocoaMQTT5, didPublishRec id: UInt16, pubRecData: MqttDecodePubRec?) {
        TRACE("id: \(id)")
        if pubRecData != nil {
            print("pubRecData reasonCode: \(String(describing: pubRecData!.reasonCode))")
        }
    }

    func mqtt5(_ mqtt5: CocoaMQTT5, didPublishComplete id: UInt16, pubCompData: MqttDecodePubComp?) {
        TRACE("id: \(id)")
        if pubCompData != nil {
            print("pubCompData reasonCode: \(String(describing: pubCompData!.reasonCode))")
        }
    }

    func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveMessage message: CocoaMQTT5Message, id: UInt16, publishData: MqttDecodePublish?) {
        if publishData != nil {
            print("publish.contentType \(String(describing: publishData!.contentType))")
        }

        TRACE("message: \(message.string.description), id: \(id)")
        let name = NSNotification.Name(rawValue: "MQTTMessageNotification" + animal!)

        NotificationCenter.default.post(
            name: name,
            object: self,
            userInfo: ["message": message.string!, "topic": message.topic, "id": id, "animal": animal as Any]
        )
    }

    func mqtt5(_ mqtt5: CocoaMQTT5, didSubscribeTopics success: NSDictionary, failed: [String], subAckData: MqttDecodeSubAck?) {
        TRACE("subscribed: \(success), failed: \(failed)")
        if subAckData != nil {
            print("subAckData.reasonCodes \(String(describing: subAckData!.reasonCodes))")
        }
    }

    func mqtt5(_ mqtt5: CocoaMQTT5, didUnsubscribeTopics topics: [String], unsubAckData: MqttDecodeUnsubAck?) {
        TRACE("topic: \(topics)")
        if unsubAckData != nil {
            print("unsubAckData.reasonCodes \(String(describing: unsubAckData!.reasonCodes))")
        }
        print("----------------------")
    }

    func mqtt5DidPing(_ mqtt5: CocoaMQTT5) {
        TRACE()
    }

    func mqtt5DidReceivePong(_ mqtt5: CocoaMQTT5) {
        TRACE()
    }

    func mqtt5DidDisconnect(_ mqtt5: CocoaMQTT5, withError err: Error?) {
        TRACE("\(err.description)")
        let name = NSNotification.Name(rawValue: "MQTTMessageNotificationDisconnect")
        NotificationCenter.default.post(name: name, object: nil)
    }
}

let myCert = "myCert"

extension ViewController: CocoaMQTTDelegate {
    // self signed delegate
    func mqttUrlSession(_ mqtt: CocoaMQTT, didReceiveTrust trust: SecTrust, didReceiveChallenge
                        challenge: URLAuthenticationChallenge,
                        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let certData = Data(base64Encoded: myCert as String)!

            if let trust = challenge.protectionSpace.serverTrust,
               let cert = SecCertificateCreateWithData(nil, certData as CFData) {
                let certs = [cert]
                SecTrustSetAnchorCertificates(trust, certs as CFArray)

                completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: trust))
                return
            }
        }

        completionHandler(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
    }

    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        TRACE("ack: \(ack)")

        if ack == .accept {
            mqtt.subscribe("chat/room/animals/client/+", qos: CocoaMQTTQoS.qos1)
            let chatViewController = storyboard?.instantiateViewController(withIdentifier: "ChatViewController") as? ChatViewController
            chatViewController?.mqtt = mqtt
            chatViewController?.mqttVersion = mqttVesion
            navigationController!.pushViewController(chatViewController!, animated: true)
        }
    }

    func mqtt(_ mqtt: CocoaMQTT, didStateChangeTo state: CocoaMQTTConnState) {
        TRACE("new state: \(state)")
    }

    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        TRACE("message: \(message.string.description), id: \(id)")
    }

    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        TRACE("id: \(id)")
    }

    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16 ) {
        TRACE("message: \(message.string.description), id: \(id)")

        let name = NSNotification.Name(rawValue: "MQTTMessageNotification" + animal!)
        NotificationCenter.default.post(name: name, object: self, userInfo: ["message": message.string!, "topic": message.topic, "id": id])
    }

    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        TRACE("subscribed: \(success), failed: \(failed)")
    }

    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {
        TRACE("topic: \(topics)")
    }

    func mqttDidPing(_ mqtt: CocoaMQTT) {
        TRACE()
    }

    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        TRACE()
    }

    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        TRACE("\(err.description)")
    }
}

extension ViewController: UITabBarControllerDelegate {
    // Prevent automatic popToRootViewController on double-tap of UITabBarController
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        return viewController != tabBarController.selectedViewController
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        print("tabbar index: \(tabBarController.selectedIndex)")
    }
}

extension ViewController {
    func TRACE(_ message: String = "", fun: String = #function) {
        let names = fun.components(separatedBy: ":")
        var prettyName: String
        if names.count == 2 {
            prettyName = names[0]
        } else {
            prettyName = names[1]
        }

        if fun == "mqttDidDisconnect(_:withError:)" {
            prettyName = "didDisconnect"
        }

        print("[TRACE] [\(prettyName)]: \(message)")
    }
}

extension Optional {
    // Unwrap optional value for printing log only
    var description: String {
        if let self = self {
            return "\(self)"
        }
        return ""
    }
}
