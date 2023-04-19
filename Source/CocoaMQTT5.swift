//
//  CocoaMQTT5.swift
//  CocoaMQTT5
//
//  Created by Feng Lee<feng@eqmtt.io> on 14/8/3.
//  Copyright (c) 2015 emqx.io. All rights reserved.
//

import Foundation
import MqttCocoaAsyncSocket

/**
 * Connection State
 */
@objc public enum CocoaMQTTConnState: UInt8, CustomStringConvertible {
    case disconnected = 0
    case connecting
    case connected

    public var description: String {
        switch self {
        case .connecting:   return "connecting"
        case .connected:    return "connected"
        case .disconnected: return "disconnected"
        }
    }
}

/// CocoaMQTT5 Delegate
@objc public protocol CocoaMQTT5Delegate {
    ///
    func mqtt5(_ mqtt5: CocoaMQTT5, didConnectAck ack: CocoaMQTTCONNACKReasonCode, connAckData: MqttDecodeConnAck?)

    ///
    func mqtt5(_ mqtt5: CocoaMQTT5, didPublishMessage message: CocoaMQTT5Message, id: UInt16)

    ///
    func mqtt5(_ mqtt5: CocoaMQTT5, didPublishAck id: UInt16, pubAckData: MqttDecodePubAck?)

    ///
    func mqtt5(_ mqtt5: CocoaMQTT5, didPublishRec id: UInt16, pubRecData: MqttDecodePubRec?)

    ///
    func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveMessage message: CocoaMQTT5Message, id: UInt16, publishData: MqttDecodePublish?)

    ///
    func mqtt5(_ mqtt5: CocoaMQTT5, didSubscribeTopics success: NSDictionary, failed: [String], subAckData: MqttDecodeSubAck?)

    ///
    func mqtt5(_ mqtt5: CocoaMQTT5, didUnsubscribeTopics topics: [String], unsubAckData: MqttDecodeUnsubAck?)

    ///
    func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveDisconnectReasonCode reasonCode: CocoaMQTTDISCONNECTReasonCode)

    ///
    func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveAuthReasonCode reasonCode: CocoaMQTTAUTHReasonCode)

    ///
    func mqtt5DidPing(_ mqtt5: CocoaMQTT5)

    ///
    func mqtt5DidReceivePong(_ mqtt5: CocoaMQTT5)

    ///
    func mqtt5DidDisconnect(_ mqtt5: CocoaMQTT5, withError err: Error?)

    /// Manually validate SSL/TLS server certificate.
    ///
    /// This method will be called if enable  `allowUntrustCACertificate`
    @objc optional func mqtt5(_ mqtt5: CocoaMQTT5, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void)

    @objc optional func mqtt5UrlSession(_ mqtt: CocoaMQTT5, didReceiveTrust trust: SecTrust, didReceiveChallenge challenge: URLAuthenticationChallenge,
                                        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)

    ///
    @objc optional func mqtt5(_ mqtt5: CocoaMQTT5, didPublishComplete id: UInt16, pubCompData: MqttDecodePubComp?)

    ///
    @objc optional func mqtt5(_ mqtt5: CocoaMQTT5, didStateChangeTo state: CocoaMQTTConnState)
}

/// set mqtt version to 5.0
public func setMqtt5Version() {
    if let storage = CocoaMQTTStorage() {
        storage.setMQTTVersion("5.0")
    }
}

/**
 * Blueprint of the MQTT Client
 */
protocol CocoaMQTT5Client {
    /* Basic Properties */

    var host: String { get set }
    var port: UInt16 { get set }
    var clientID: String { get }
    var username: String? {get set}
    var password: String? {get set}
    var cleanSession: Bool {get set}
    var keepAlive: UInt16 {get set}
    var willMessage: CocoaMQTT5Message? {get set}
    var connectProperties: MqttConnectProperties? {get set}
    var authProperties: MqttAuthProperties? {get set}

    /* Basic Properties */

    /* CONNNEC/DISCONNECT */

    func connect() -> Bool
    func connect(timeout: TimeInterval) -> Bool
    func disconnect()
    func ping()

    /* CONNNEC/DISCONNECT */

    /* PUBLISH/SUBSCRIBE */

    func subscribe(_ topic: String, qos: CocoaMQTTQoS)
    func subscribe(_ topics: [MqttSubscription])

    func unsubscribe(_ topic: String)
    func unsubscribe(_ topics: [MqttSubscription])

    // swiftlint:disable:next function_parameter_count
    func publish(_ topic: String, withString string: String, qos: CocoaMQTTQoS, DUP: Bool, retained: Bool, properties: MqttPublishProperties) -> Int
    func publish(_ message: CocoaMQTT5Message, DUP: Bool, retained: Bool, properties: MqttPublishProperties) -> Int

    /* PUBLISH/SUBSCRIBE */
}

/// MQTT Client
///
/// - Note: MGCDAsyncSocket need delegate to extend NSObject
public class CocoaMQTT5: NSObject, CocoaMQTT5Client {
    public weak var delegate: CocoaMQTT5Delegate?

    private var version = "5.0"

    public var host = "localhost"

    public var port: UInt16 = 1883

    public var clientID: String

    public var username: String?

    public var password: String?

    /// Clean Session flag. Default is true
    ///
    /// - TODO: What's behavior each Clean Session flags???
    public var cleanSession = true

    /// Setup a **Last Will Message** to client before connecting to broker
    public var willMessage: CocoaMQTT5Message?

    /// Enable backgounding socket if running on iOS platform. Default is true
    ///
    /// - Note:
    public var backgroundOnSocket: Bool {
        get { return (self.socket as? CocoaMQTTSocket)?.backgroundOnSocket ?? true }
        set { (self.socket as? CocoaMQTTSocket)?.backgroundOnSocket = newValue }
    }

    /// Delegate Executed queue. Default is `DispatchQueue.main`
    ///
    /// The delegate/closure callback function will be committed asynchronously to it
    public var delegateQueue = DispatchQueue.main

    public var connState = CocoaMQTTConnState.disconnected {
        didSet {
            executeOnDelegateQueue {
                self.delegate?.mqtt5?(self, didStateChangeTo: self.connState)
                self.didChangeState(self, self.connState)
            }
        }
    }

    // deliver
    private var deliver = CocoaMQTTDeliver()

    /// Re-deliver the un-acked messages
    public var deliverTimeout: Double {
        get { return deliver.retryTimeInterval }
        set { deliver.retryTimeInterval = newValue }
    }

    /// Message queue size. default 1000
    ///
    /// The new publishing messages of Qos1/Qos2 will be drop, if the queue is full
    public var messageQueueSize: UInt {
        get { return deliver.mqueueSize }
        set { deliver.mqueueSize = newValue }
    }

    /// In-flight window size. default 10
    public var inflightWindowSize: UInt {
        get { return deliver.inflightWindowSize }
        set { deliver.inflightWindowSize = newValue }
    }

    /// Keep alive time interval
    public var keepAlive: UInt16 = 60
    private var aliveTimer: CocoaMQTTTimer?

    /// Enable auto-reconnect mechanism
    public var autoReconnect = false

    /// Reconnect time interval
    ///
    /// - note: This value will be increased with `autoReconnectTimeInterval *= 2`
    ///         if reconnect failed
    public var autoReconnectTimeInterval: UInt16 = 1 // starts from 1 second

    /// Maximum auto reconnect time interval
    ///
    /// The timer starts from `autoReconnectTimeInterval` second and grows exponentially until this value
    /// After that, it uses this value for subsequent requests.
    public var maxAutoReconnectTimeInterval: UInt16 = 128 // 128 seconds

    /// 3.1.2.11 CONNECT Properties
    public var connectProperties: MqttConnectProperties?

    /// 3.15.2.2 AUTH Properties
    public var authProperties: MqttAuthProperties?

    private var reconnectTimeInterval: UInt16 = 0

    private var autoReconnTimer: CocoaMQTTTimer?
    private var isInternalDisconnected = false

    /// Console log level
    public var logLevel: CocoaMQTTLoggerLevel {
        get {
            return CocoaMQTTLogger.logger.minLevel
        }
        set {
            CocoaMQTTLogger.logger.minLevel = newValue
        }
    }

    /// Enable SSL connection
    public var enableSSL: Bool {
        get { return self.socket.enableSSL }
        set { socket.enableSSL = newValue }
    }

    ///
    public var sslSettings: [String: NSObject]? {
        get { return (self.socket as? CocoaMQTTSocket)?.sslSettings }
        set { (self.socket as? CocoaMQTTSocket)?.sslSettings = newValue }
    }

    /// Allow self-signed ca certificate.
    ///
    /// Default is false
    public var allowUntrustCACertificate: Bool {
        get { return (self.socket as? CocoaMQTTSocket)?.allowUntrustCACertificate ?? false }
        set { (self.socket as? CocoaMQTTSocket)?.allowUntrustCACertificate = newValue }
    }

    /// The subscribed topics in current communication
    public var subscriptions: [String: CocoaMQTTQoS] = [:]

    fileprivate var subscriptionsWaitingAck: [UInt16: [MqttSubscription]] = [:]
    fileprivate var unsubscriptionsWaitingAck: [UInt16: [MqttSubscription]] = [:]

    /// Sending messages
    fileprivate var sendingMessages: [UInt16: CocoaMQTT5Message] = [:]

    /// message id counter
    private var _msgid: UInt16 = 0
    fileprivate var socket: CocoaMQTTSocketProtocol
    fileprivate var reader: CocoaMQTTReader?

    // Closures
    public var didConnectAck: (CocoaMQTT5, CocoaMQTTCONNACKReasonCode, MqttDecodeConnAck?) -> Void = { _, _, _ in }
    public var didPublishMessage: (CocoaMQTT5, CocoaMQTT5Message, UInt16) -> Void = { _, _, _ in }
    public var didPublishAck: (CocoaMQTT5, UInt16, MqttDecodePubAck?) -> Void = { _, _, _ in }
    public var didPublishRec: (CocoaMQTT5, UInt16, MqttDecodePubRec?) -> Void = { _, _, _ in }
    public var didReceiveMessage: (CocoaMQTT5, CocoaMQTT5Message, UInt16, MqttDecodePublish?) -> Void = { _, _, _, _ in }
    public var didSubscribeTopics: (CocoaMQTT5, NSDictionary, [String], MqttDecodeSubAck?) -> Void = { _, _, _, _  in }
    public var didUnsubscribeTopics: (CocoaMQTT5, [String], MqttDecodeUnsubAck?) -> Void = { _, _, _ in }
    public var didPing: (CocoaMQTT5) -> Void = { _ in }
    public var didReceivePong: (CocoaMQTT5) -> Void = { _ in }
    public var didDisconnect: (CocoaMQTT5, Error?) -> Void = { _, _ in }
    public var didDisconnectReasonCode: (CocoaMQTT5, CocoaMQTTDISCONNECTReasonCode) -> Void = { _, _ in }
    public var didAuthReasonCode: (CocoaMQTT5, CocoaMQTTAUTHReasonCode) -> Void = { _, _ in }
    public var didReceiveTrust: (CocoaMQTT5, SecTrust, @escaping (Bool) -> Swift.Void) -> Void = { _, _, _ in }
    public var didCompletePublish: (CocoaMQTT5, UInt16, MqttDecodePubComp?) -> Void = { _, _, _ in }
    public var didChangeState: (CocoaMQTT5, CocoaMQTTConnState) -> Void = { _, _ in }

    /// Initial client object
    ///
    /// - Parameters:
    ///   - clientID: Client Identifier
    ///   - host: The MQTT broker host domain or IP address. Default is "localhost"
    ///   - port: The MQTT service port of host. Default is 1883
    public init(clientID: String, host: String = "localhost", port: UInt16 = 1883, socket: CocoaMQTTSocketProtocol = CocoaMQTTSocket()) {
        self.clientID = clientID
        self.host = host
        self.port = port
        self.socket = socket
        super.init()
        deliver.delegate = self
        if let storage = CocoaMQTTStorage() {
            storage.setMQTTVersion("5.0")
        } else {
            printWarning("Localstorage initial failed for key: \(clientID)")
        }
    }

    deinit {
        aliveTimer?.suspend()
        autoReconnTimer?.suspend()

        socket.setDelegate(nil, delegateQueue: nil)
        socket.disconnect()
    }

    fileprivate func send(_ frame: Frame, tag: Int = 0) {
        printDebug("SEND: \(frame)")
        let data = frame.bytes(version: version)

        socket.write(Data(bytes: data, count: data.count), withTimeout: 5, tag: tag)
    }

    fileprivate func sendConnectFrame() {
        var connect = FrameConnect(clientID: clientID)
        connect.keepAlive = keepAlive
        connect.username = username
        connect.password = password
        connect.willMsg5 = willMessage
        connect.cleansess = cleanSession

        connect.connectProperties = connectProperties

        send(connect)
        reader!.start()
    }

    fileprivate func nextMessageID() -> UInt16 {
        if _msgid == UInt16.max {
            _msgid = 0
        }
        _msgid += 1
        return _msgid
    }

    fileprivate func puback(_ type: FrameType, msgid: UInt16) {
        switch type {
        case .puback:
            send(FramePubAck(msgid: msgid, reasonCode: CocoaMQTTPUBACKReasonCode.success))
        case .pubrec:
            send(FramePubRec(msgid: msgid, reasonCode: CocoaMQTTPUBRECReasonCode.success))
        case .pubcomp:
            send(FramePubComp(msgid: msgid, reasonCode: CocoaMQTTPUBCOMPReasonCode.success))
        default: return
        }
    }

    /// Connect to MQTT broker
    ///
    /// - Returns:
    ///   - Bool: It indicates whether successfully calling socket connect function.
    ///           Not yet established correct MQTT session
    public func connect() -> Bool {
        return connect(timeout: -1)
    }

    /// Connect to MQTT broker
    /// - Parameters:
    ///   - timeout: Connect timeout
    /// - Returns:
    ///   - Bool: It indicates whether successfully calling socket connect function.
    ///           Not yet established correct MQTT session
    public func connect(timeout: TimeInterval) -> Bool {
        socket.setDelegate(self, delegateQueue: delegateQueue)
        reader = CocoaMQTTReader(socket: socket, delegate: self)
        do {
            if timeout > 0 {
                try socket.connect(toHost: self.host, onPort: self.port, withTimeout: timeout)
            } else {
                try socket.connect(toHost: self.host, onPort: self.port)
            }

            delegateQueue.async { [weak self] in
                guard let self = self else { return }
                self.connState = .connecting
            }

            return true
        } catch let error as NSError {
            printError("socket connect error: \(error.description)")
            return false
        }
    }

    /// Send a DISCONNECT packet to the broker then close the connection
    ///
    /// - Note: Only can be called from outside.
    ///         If you want to disconnect from inside framework, call internal_disconnect()
    ///         disconnect expectedly
    public func disconnect() {
        internal_disconnect()
    }

    public func disconnect(reasonCode: CocoaMQTTDISCONNECTReasonCode, userProperties: [String: String] ) {
        internal_disconnect_withProperties(reasonCode: reasonCode, userProperties: userProperties)
    }

    /// Disconnect unexpectedly
    func internal_disconnect() {
        isInternalDisconnected = true
        send(FrameDisconnect(disconnectReasonCode: CocoaMQTTDISCONNECTReasonCode.normalDisconnection), tag: -0xE0)
        socket.disconnect()
    }

    func internal_disconnect_withProperties(reasonCode: CocoaMQTTDISCONNECTReasonCode, userProperties: [String: String] ) {
        isInternalDisconnected = true
        var frameDisconnect = FrameDisconnect(disconnectReasonCode: reasonCode)
        frameDisconnect.userProperties = userProperties
        send(frameDisconnect, tag: -0xE0)
        socket.disconnect()
    }
    /// Send a PING request to broker
    public func ping() {
        printDebug("ping")
        send(FramePingReq(), tag: -0xC0)

        executeOnDelegateQueue {
            self.delegate?.mqtt5DidPing(self)
            self.didPing(self)
        }
    }

    /// Publish a message to broker
    ///
    /// - Parameters:
    ///    - topic: Topic Name. It can not contain '#', '+' wildcards
    ///    - string: Payload string
    ///    - qos: Qos. Default is Qos1
    ///    - retained: Retained flag. Mark this message is a retained message. default is false
    ///    - properties: Publish Properties
    /// - Returns:
    ///     - 0 will be returned, if the message's qos is qos0
    ///     - 1-65535 will be returned, if the messages's qos is qos1/qos2
    ///     - -1 will be returned, if the messages queue is full
    @discardableResult
    public func publish(_ topic: String, withString string: String, qos: CocoaMQTTQoS = .qos1, DUP: Bool = false,
                        retained: Bool = false, properties: MqttPublishProperties) -> Int {
        var fixQus = qos
        if !DUP {
            fixQus = .qos0
        }
        let message = CocoaMQTT5Message(topic: topic, string: string, qos: fixQus, retained: retained)
        return publish(message, DUP: DUP, retained: retained, properties: properties)
    }

    /// Publish a message to broker
    ///
    /// - Parameters:
    ///   - message: Message
    ///   - properties: Publish Properties
    @discardableResult
    public func publish(_ message: CocoaMQTT5Message, DUP: Bool = false, retained: Bool = false, properties: MqttPublishProperties) -> Int {
        let msgid: UInt16

        if message.qos == .qos0 {
            msgid = 0
        } else {
            msgid = nextMessageID()
        }

        printDebug("message.topic \(message.topic )   = message.payload \(message.payload)")

        var frame = FramePublish(topic: message.topic,
                                 payload: message.payload,
                                 qos: message.qos,
                                 msgid: msgid)
        frame.qos = message.qos
        frame.dup = DUP
        frame.publishProperties = properties
        frame.retained = message.retained

        delegateQueue.async {
            self.sendingMessages[msgid] = message
        }

        // Push frame to deliver message queue
        guard deliver.add(frame) else {
            delegateQueue.async {
                self.sendingMessages.removeValue(forKey: msgid)
            }
            return -1
        }

        return Int(msgid)
    }

    /// Subscribe a `<Topic Name>/<Topic Filter>`
    ///
    /// - Parameters:
    ///   - topic: Topic Name or Topic Filter
    ///   - qos: Qos. Default is qos1
    public func subscribe(_ topic: String, qos: CocoaMQTTQoS = .qos1) {
        let filter = MqttSubscription(topic: topic, qos: qos)
        return subscribe([filter])
    }

    /// Subscribe a lists of topics
    ///
    /// - Parameters:
    ///   - topics: A list of tuples presented by `(<Topic Names>/<Topic Filters>, Qos)`
    public func subscribe(_ topics: [MqttSubscription]) {
        let msgid = nextMessageID()
        let frame = FrameSubscribe(msgid: msgid, subscriptionList: topics)
        send(frame, tag: Int(msgid))
        subscriptionsWaitingAck[msgid] = topics
    }

    /// Unsubscribe a Topic
    ///
    /// - Parameters:
    ///   - topic: A Topic Name or Topic Filter
    public func unsubscribe(_ topic: String) {
        let filter = MqttSubscription(topic: topic)
        return unsubscribe([filter])
    }

    /// Unsubscribe a list of topics
    ///
    /// - Parameters:
    ///   - topics: A list of `<Topic Names>/<Topic Filters>`
    public func unsubscribe(_ topics: [MqttSubscription]) {
        let msgid = nextMessageID()
        let frame = FrameUnsubscribe(msgid: msgid, topics: topics)
        unsubscriptionsWaitingAck[msgid] = topics
        send(frame, tag: Int(msgid))
    }

    ///  Authentication exchange
    ///
    ///
    public func auth(reasonCode: CocoaMQTTAUTHReasonCode, authProperties: MqttAuthProperties) {
        printDebug("auth")
        let frame = FrameAuth(reasonCode: reasonCode, authProperties: authProperties)

        send(frame)
    }
}

// MARK: CocoaMQTTDeliverProtocol
extension CocoaMQTT5: CocoaMQTTDeliverProtocol {
    func deliver(_ deliver: CocoaMQTTDeliver, wantToSend frame: Frame) {
        if let publish = frame as? FramePublish {
            let msgid = publish.msgid
            var message: CocoaMQTT5Message?

            if let sendingMessage = sendingMessages[msgid] {
                message = sendingMessage
                // printError("Want send \(frame), but not found in CocoaMQTT cache")
            } else {
                message = CocoaMQTT5Message(topic: publish.topic, payload: publish.payload())
            }

            send(publish, tag: Int(msgid))

            if let message = message {
                self.delegate?.mqtt5(self, didPublishMessage: message, id: msgid)
                self.didPublishMessage(self, message, msgid)
            }
        } else if let pubrel = frame as? FramePubRel {
            // -- Send PUBREL
            send(pubrel, tag: Int(pubrel.msgid))
        }
    }
}

extension CocoaMQTT5 {
    func executeOnDelegateQueue(_ fun: @escaping () -> Void) {
        delegateQueue.async { [weak self] in
            guard self != nil else { return }
            fun()
        }
    }
}

// MARK: - CocoaMQTTSocketDelegate
extension CocoaMQTT5: CocoaMQTTSocketDelegate {
    public func socketConnected(_ socket: CocoaMQTTSocketProtocol) {
        sendConnectFrame()
    }

    public func socket(_ socket: CocoaMQTTSocketProtocol,
                       didReceive trust: SecTrust,
                       completionHandler: @escaping (Bool) -> Swift.Void) {
        printDebug("Call the SSL/TLS manually validating function")

        delegate?.mqtt5?(self, didReceive: trust, completionHandler: completionHandler)
        didReceiveTrust(self, trust, completionHandler)
    }

    public func socketUrlSession(_ socket: CocoaMQTTSocketProtocol, didReceiveTrust trust: SecTrust, didReceiveChallenge challenge: URLAuthenticationChallenge,
                                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        printDebug("Call the SSL/TLS manually validating function - socketUrlSession")

        delegate?.mqtt5UrlSession?(self, didReceiveTrust: trust, didReceiveChallenge: challenge, completionHandler: completionHandler)
    }

    // ?
    public func socketDidSecure(_ sock: MGCDAsyncSocket) {
        printDebug("Socket has successfully completed SSL/TLS negotiation")
        sendConnectFrame()
    }

    public func socket(_ socket: CocoaMQTTSocketProtocol, didWriteDataWithTag tag: Int) {
        // XXX: How to print writed bytes??
    }

    public func socket(_ socket: CocoaMQTTSocketProtocol, didRead data: Data, withTag tag: Int) {
        let etag = CocoaMQTTReadTag(rawValue: tag)!
        var bytes = [UInt8]([0])
        switch etag {
        case CocoaMQTTReadTag.header:
            data.copyBytes(to: &bytes, count: 1)
            reader!.headerReady(bytes[0])
        case CocoaMQTTReadTag.length:
            data.copyBytes(to: &bytes, count: 1)
            reader!.lengthReady(bytes[0])
        case CocoaMQTTReadTag.payload:
            reader!.payloadReady(data)
        }
    }

    public func socketDidDisconnect(_ socket: CocoaMQTTSocketProtocol, withError err: Error?) {
        // Clean up
        socket.setDelegate(nil, delegateQueue: nil)
        connState = .disconnected

        delegate?.mqtt5DidDisconnect(self, withError: err)
        didDisconnect(self, err)

        guard !isInternalDisconnected else {
            return
        }

        guard autoReconnect else {
            return
        }

        if reconnectTimeInterval == 0 {
            reconnectTimeInterval = autoReconnectTimeInterval
        }

        // Start reconnector once socket error occurred
        printInfo("Try reconnect to server after \(reconnectTimeInterval)s")
        autoReconnTimer = CocoaMQTTTimer.after(Double(reconnectTimeInterval), name: "autoReconnTimer", { [weak self] in
            guard let self = self else { return }
            if self.reconnectTimeInterval < self.maxAutoReconnectTimeInterval {
                self.reconnectTimeInterval *= 2
            } else {
                self.reconnectTimeInterval = self.maxAutoReconnectTimeInterval
            }
            _ = self.connect()
        })
    }
}

// MARK: - CocoaMQTTReaderDelegate
extension CocoaMQTT5: CocoaMQTTReaderDelegate {
    func didReceive(_ reader: CocoaMQTTReader, disconnect: FrameDisconnect) {
        delegate?.mqtt5(self, didReceiveDisconnectReasonCode: disconnect.receiveReasonCode!)
        didDisconnectReasonCode(self, disconnect.receiveReasonCode!)
    }

    func didReceive(_ reader: CocoaMQTTReader, auth: FrameAuth) {
        delegate?.mqtt5(self, didReceiveAuthReasonCode: auth.receiveReasonCode!)
        didAuthReasonCode(self, auth.receiveReasonCode!)
    }

    func didReceive(_ reader: CocoaMQTTReader, connack: FrameConnAck) {
        printDebug("RECV: \(connack)")

        if connack.reasonCode == .success {
            // Disable auto-reconnect

            reconnectTimeInterval = 0
            autoReconnTimer = nil
            isInternalDisconnected = false

            // Start keepalive timer

            let interval = Double(keepAlive <= 0 ? 60 : keepAlive)

            aliveTimer = CocoaMQTTTimer.every(interval, name: "aliveTimer") { [weak self] in
                guard let self = self else { return }
                self.delegateQueue.async {
                    guard self.connState == .connected else {
                        self.aliveTimer = nil
                        return
                    }
                    self.ping()
                }
            }

            // recover session if enable

            if cleanSession {
                deliver.cleanAll()
            } else {
                if let storage = CocoaMQTTStorage(by: clientID) {
                    deliver.recoverSessionBy(storage)
                } else {
                    printWarning("Localstorage initial failed for key: \(clientID)")
                }
            }

            connState = .connected
        } else {
            connState = .disconnected
            internal_disconnect()
        }

        delegate?.mqtt5(self, didConnectAck: connack.reasonCode!, connAckData: connack.connackProperties)
        didConnectAck(self, connack.reasonCode!, connack.connackProperties)
    }

    func didReceive(_ reader: CocoaMQTTReader, publish: FramePublish) {
        printDebug("RECV: \(publish)")

        let message = CocoaMQTT5Message(topic: publish.mqtt5Topic, payload: publish.payload5(), qos: publish.qos, retained: publish.retained)

        message.duplicated = publish.dup

        printInfo("Received message: \(message)")
        delegate?.mqtt5(self, didReceiveMessage: message, id: publish.msgid, publishData: publish.publishRecProperties)
        didReceiveMessage(self, message, publish.msgid, publish.publishRecProperties)

        if message.qos == .qos1 {
            puback(FrameType.puback, msgid: publish.msgid)
        } else if message.qos == .qos2 {
            puback(FrameType.pubrec, msgid: publish.msgid)
        }
    }

    func didReceive(_ reader: CocoaMQTTReader, puback: FramePubAck) {
        printDebug("RECV: \(puback)")

        deliver.ack(by: puback)

        delegate?.mqtt5(self, didPublishAck: puback.msgid, pubAckData: puback.pubAckProperties)
        didPublishAck(self, puback.msgid, puback.pubAckProperties)
    }

    func didReceive(_ reader: CocoaMQTTReader, pubrec: FramePubRec) {
        printDebug("RECV: \(pubrec)")

        deliver.ack(by: pubrec)

        delegate?.mqtt5(self, didPublishRec: pubrec.msgid, pubRecData: pubrec.pubRecProperties)
        didPublishRec(self, pubrec.msgid, pubrec.pubRecProperties)
    }

    func didReceive(_ reader: CocoaMQTTReader, pubrel: FramePubRel) {
        printDebug("RECV: \(pubrel)")

        puback(FrameType.pubcomp, msgid: pubrel.msgid)
    }

    func didReceive(_ reader: CocoaMQTTReader, pubcomp: FramePubComp) {
        printDebug("RECV: \(pubcomp)")

        deliver.ack(by: pubcomp)

        delegate?.mqtt5?(self, didPublishComplete: pubcomp.msgid, pubCompData: pubcomp.pubCompProperties)
        didCompletePublish(self, pubcomp.msgid, pubcomp.pubCompProperties)
    }

    func didReceive(_ reader: CocoaMQTTReader, suback: FrameSubAck) {
        printDebug("RECV: \(suback)")
        guard let topicsAndQos = subscriptionsWaitingAck.removeValue(forKey: suback.msgid) else {
            printWarning("UNEXPECT SUBACK Received: \(suback)")
            return
        }

        guard topicsAndQos.count == suback.grantedQos.count else {
            printWarning("UNEXPECT SUBACK Recivied: \(suback)")
            return
        }

        let success = NSMutableDictionary()
        var failed = [String]()
        for (idx, subscriptionList) in topicsAndQos.enumerated() {
            if suback.grantedQos[idx] != .FAILURE {
                subscriptions[subscriptionList.topic] = suback.grantedQos[idx]
                success[subscriptionList.topic] = suback.grantedQos[idx].rawValue
            } else {
                failed.append(subscriptionList.topic)
            }
        }

        delegate?.mqtt5(self, didSubscribeTopics: success, failed: failed, subAckData: suback.subAckProperties)
        didSubscribeTopics(self, success, failed, suback.subAckProperties)
    }

    func didReceive(_ reader: CocoaMQTTReader, unsuback: FrameUnsubAck) {
        printDebug("RECV: \(unsuback)")

        guard let topics = unsubscriptionsWaitingAck.removeValue(forKey: unsuback.msgid) else {
            printWarning("UNEXPECT UNSUBACK Received: \(unsuback.msgid)")
            return
        }
        // Remove local subscription
        var removeTopics: [String] = []
        for t in topics {
            removeTopics.append(t.topic)
            subscriptions.removeValue(forKey: t.topic)
        }

        delegate?.mqtt5(self, didUnsubscribeTopics: removeTopics, unsubAckData: unsuback.unSubAckProperties)
        didUnsubscribeTopics(self, removeTopics, unsuback.unSubAckProperties)
    }

    func didReceive(_ reader: CocoaMQTTReader, pingresp: FramePingResp) {
        printDebug("RECV: \(pingresp)")

        delegate?.mqtt5DidReceivePong(self)
        didReceivePong(self)
    }
}
