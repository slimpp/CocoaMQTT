//
//  CocoaMQTT.swift
//  CocoaMQTT
//
//  Created by Feng Lee<feng@eqmtt.io> on 14/8/3.
//  Copyright (c) 2015 emqx.io. All rights reserved.
//

import Foundation

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

/**
 * Conn Ack
 */
@objc public enum CocoaMQTTConnAck: UInt8, CustomStringConvertible {
    case accept  = 0
    case unacceptableProtocolVersion
    case identifierRejected
    case serverUnavailable
    case badUsernameOrPassword
    case notAuthorized
    case reserved
    
    public var description: String {
        switch self {
            case .accept:                       return "accept"
            case .unacceptableProtocolVersion:  return "unacceptableProtocolVersion"
            case .identifierRejected:           return "identifierRejected"
            case .serverUnavailable:            return "serverUnavailable"
            case .badUsernameOrPassword:        return "badUsernameOrPassword"
            case .notAuthorized:                return "notAuthorized"
            case .reserved:                     return "reserved"
        }
    }
}

/// CocoaMQTT Delegate
@objc public protocol CocoaMQTTDelegate {

    ///
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck)
    
    ///
    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16)
    
    ///
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16)
    
    ///
    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16 )
    
    ///
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String])
    
    ///
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String])
    
    ///
    func mqttDidPing(_ mqtt: CocoaMQTT)
    
    ///
    func mqttDidReceivePong(_ mqtt: CocoaMQTT)
    
    ///
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?)
    
    /// Manually validate SSL/TLS server certificate.
    ///
    /// This method will be called if enable  `allowUntrustCACertificate`
    @objc optional func mqtt(_ mqtt: CocoaMQTT, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void)
    
    ///
    @objc optional func mqtt(_ mqtt: CocoaMQTT, didPublishComplete id: UInt16)
    
    ///
    @objc optional func mqtt(_ mqtt: CocoaMQTT, didStateChangeTo state: CocoaMQTTConnState)
}

/**
 * Blueprint of the MQTT Client
 */
protocol CocoaMQTTClient {
    
    /* Basic Properties */
    
    var host: String { get set }
    var port: UInt16 { get set }
    var clientID: String { get }
    var username: String? {get set}
    var password: String? {get set}
    var cleanSession: Bool {get set}
    var keepAlive: UInt16 {get set}
    var willMessage: CocoaMQTTMessage? {get set}
    
    /* Basic Properties */

    /* CONNNEC/DISCONNECT */
    
    func connect() -> Bool
    func connect(timeout:TimeInterval) -> Bool
    func disconnect()
    func ping()
    
    /* CONNNEC/DISCONNECT */

    /* PUBLISH/SUBSCRIBE */
    
    func subscribe(_ topic: String, qos: CocoaMQTTQoS)
    func subscribe(_ topics: [(String, CocoaMQTTQoS)])
    
    func unsubscribe(_ topic: String)
    func unsubscribe(_ topics: [String])
    
    func publish(_ topic: String, withString string: String, qos: CocoaMQTTQoS, retained: Bool) -> Int
    func publish(_ message: CocoaMQTTMessage) -> Int

    /* PUBLISH/SUBSCRIBE */
}


/// MQTT Client
///
/// - Note: GCDAsyncSocket need delegate to extend NSObject
public class CocoaMQTT: NSObject, CocoaMQTTClient {
    
    public weak var delegate: CocoaMQTTDelegate?
    
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
    public var willMessage: CocoaMQTTMessage?
    
    /// Enable backgounding socket if running on iOS platform. Default is true
    ///
    /// - Note:
    public var backgroundOnSocket: Bool {
        get {
            #if canImport(CocoaAsyncSocket)
            return (self.socket as? CocoaMQTTSocket)?.backgroundOnSocket ?? true
            #else
            return true
            #endif
        }
        set {
            #if canImport(CocoaAsyncSocket)
            (self.socket as? CocoaMQTTSocket)?.backgroundOnSocket = newValue
            #endif
        }
    }
    
    /// Delegate Executed queue. Default is `DispatchQueue.main`
    ///
    /// The delegate/closure callback function will be committed asynchronously to it
    public var delegateQueue = DispatchQueue.main
    
    public var connState = CocoaMQTTConnState.disconnected {
        didSet {
            __delegate_queue {
                self.delegate?.mqtt?(self, didStateChangeTo: self.connState)
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
    
    private var reconnectTimeInterval: UInt16 = 0
    
    private var autoReconnTimer: CocoaMQTTTimer?
    private var is_internal_disconnected = false
    
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
        get { return (self.socket as? CocoaMQTTSocket)?.sslSettings ?? nil }
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
    
    fileprivate var subscriptionsWaitingAck: [UInt16: [(String, CocoaMQTTQoS)]] = [:]
    fileprivate var unsubscriptionsWaitingAck: [UInt16: [String]] = [:]
    

    /// Sending messages
    fileprivate var sendingMessages: [UInt16: CocoaMQTTMessage] = [:]

    /// message id counter
    private var _msgid: UInt16 = 0
    fileprivate var socket: CocoaMQTTSocketProtocol
    fileprivate var reader: CocoaMQTTReader?
    
    // Closures
    public var didConnectAck: (CocoaMQTT, CocoaMQTTConnAck) -> Void = { _, _ in }
    public var didPublishMessage: (CocoaMQTT, CocoaMQTTMessage, UInt16) -> Void = { _, _, _ in }
    public var didPublishAck: (CocoaMQTT, UInt16) -> Void = { _, _ in }
    public var didReceiveMessage: (CocoaMQTT, CocoaMQTTMessage, UInt16) -> Void = { _, _, _ in }
    public var didSubscribeTopics: (CocoaMQTT, NSDictionary, [String]) -> Void = { _, _, _  in }
    public var didUnsubscribeTopics: (CocoaMQTT, [String]) -> Void = { _, _ in }
    public var didPing: (CocoaMQTT) -> Void = { _ in }
    public var didReceivePong: (CocoaMQTT) -> Void = { _ in }
    public var didDisconnect: (CocoaMQTT, Error?) -> Void = { _, _ in }
    public var didReceiveTrust: (CocoaMQTT, SecTrust, @escaping (Bool) -> Swift.Void) -> Void = { _, _, _ in }
    public var didCompletePublish: (CocoaMQTT, UInt16) -> Void = { _, _ in }
    public var didChangeState: (CocoaMQTT, CocoaMQTTConnState) -> Void = { _, _ in }
    
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
    }
    
    deinit {
		aliveTimer?.suspend()
        autoReconnTimer?.suspend()
        
        socket.setDelegate(nil, delegateQueue: nil)
        socket.disconnect()
    }

    fileprivate func send(_ frame: Frame, tag: Int = 0) {
        printDebug("SEND: \(frame)")
        let data = frame.bytes()
        socket.write(Data(bytes: data, count: data.count), withTimeout: 5, tag: tag)
    }

    fileprivate func sendConnectFrame() {
        
        var connect = FrameConnect(clientID: clientID)
        connect.keepalive = keepAlive
        connect.username = username
        connect.password = password
        connect.willMsg = willMessage
        connect.cleansess = cleanSession
        
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
            send(FramePubAck(msgid: msgid))
        case .pubrec:
            send(FramePubRec(msgid: msgid))
        case .pubcomp:
            send(FramePubComp(msgid: msgid))
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
        is_internal_disconnected = false
        internal_disconnect()
    }
    
    /// Disconnect unexpectedly
    func internal_disconnect() {
        is_internal_disconnected = true
        send(FrameDisconnect(), tag: -0xE0)
        socket.disconnect()
    }
    
    /// Send a PING request to broker
    public func ping() {
        printDebug("ping")
        send(FramePingReq(), tag: -0xC0)
        
        __delegate_queue {
            self.delegate?.mqttDidPing(self)
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
    /// - Returns:
    ///     - 0 will be returned, if the message's qos is qos0
    ///     - 1-65535 will be returned, if the messages's qos is qos1/qos2
    ///     - -1 will be returned, if the messages queue is full
    @discardableResult
    public func publish(_ topic: String, withString string: String, qos: CocoaMQTTQoS = .qos1, retained: Bool = false) -> Int {
        let message = CocoaMQTTMessage(topic: topic, string: string, qos: qos, retained: retained)
        return publish(message)
    }

    /// Publish a message to broker
    ///
    /// - Parameters:
    ///   - message: Message
    @discardableResult
    public func publish(_ message: CocoaMQTTMessage) -> Int {
        let msgid: UInt16
        
        if message.qos == .qos0 {
            msgid = 0
        } else {
            msgid = nextMessageID()
        }
        
        var frame = FramePublish(topic: message.topic,
                                 payload: message.payload,
                                 qos: message.qos,
                                 msgid: msgid)
        
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
        return subscribe([(topic, qos)])
    }
    
    /// Subscribe a lists of topics
    ///
    /// - Parameters:
    ///   - topics: A list of tuples presented by `(<Topic Names>/<Topic Filters>, Qos)`
    public func subscribe(_ topics: [(String, CocoaMQTTQoS)]) {
        let msgid = nextMessageID()
        let frame = FrameSubscribe(msgid: msgid, topics: topics)
        send(frame, tag: Int(msgid))
        subscriptionsWaitingAck[msgid] = topics
    }

    /// Unsubscribe a Topic
    ///
    /// - Parameters:
    ///   - topic: A Topic Name or Topic Filter
    public func unsubscribe(_ topic: String) {
        return unsubscribe([topic])
    }
    
    /// Unsubscribe a list of topics
    ///
    /// - Parameters:
    ///   - topics: A list of `<Topic Names>/<Topic Filters>`
    public func unsubscribe(_ topics: [String]) {
        let msgid = nextMessageID()
        let frame = FrameUnsubscribe(msgid: msgid, topics: topics)
        unsubscriptionsWaitingAck[msgid] = topics
        send(frame, tag: Int(msgid))
    }
}

// MARK: CocoaMQTTDeliverProtocol
extension CocoaMQTT: CocoaMQTTDeliverProtocol {
    
    func deliver(_ deliver: CocoaMQTTDeliver, wantToSend frame: Frame) {
        if let publish = frame as? FramePublish {
            let msgid = publish.msgid
            guard let message = sendingMessages[msgid] else {
                printError("Want send \(frame), but not found in CocoaMQTT cache")
                return
            }
            
            send(publish, tag: Int(msgid))
            
            
            self.delegate?.mqtt(self, didPublishMessage: message, id: msgid)
            self.didPublishMessage(self, message, msgid)
        
        } else if let pubrel = frame as? FramePubRel {
            // -- Send PUBREL
            send(pubrel, tag: Int(pubrel.msgid))
        }
    }
}

extension CocoaMQTT {
    
    func __delegate_queue(_ fun: @escaping () -> Void) {
        delegateQueue.async { [weak self] in
            guard let _ = self else { return }
            fun()
        }
    }
}

// MARK: - CocoaMQTTSocketDelegate
extension CocoaMQTT: CocoaMQTTSocketDelegate {
    
    public func socketConnected(_ socket: CocoaMQTTSocketProtocol) {
        sendConnectFrame()
    }
    
    public func socket(_ socket: CocoaMQTTSocketProtocol,
                         didReceive trust: SecTrust,
                         completionHandler: @escaping (Bool) -> Swift.Void) {
        
        printDebug("Call the SSL/TLS manually validating function")
        
        delegate?.mqtt?(self, didReceive: trust, completionHandler: completionHandler)
        didReceiveTrust(self, trust, completionHandler)
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
        delegate?.mqttDidDisconnect(self, withError: err)
        didDisconnect(self, err)
        
        guard is_internal_disconnected else {
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
extension CocoaMQTT: CocoaMQTTReaderDelegate {
    
    func didReceive(_ reader: CocoaMQTTReader, connack: FrameConnAck) {
        printDebug("RECV: \(connack)")

        if connack.returnCode == .accept {
            
            // Disable auto-reconnect
            
            reconnectTimeInterval = 0
            autoReconnTimer = nil
            is_internal_disconnected = false
            
            // Start keepalive timer
            
            let interval = Double(keepAlive <= 0 ? 60: keepAlive)
            
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

        delegate?.mqtt(self, didConnectAck: connack.returnCode)
        didConnectAck(self, connack.returnCode)
    }

    func didReceive(_ reader: CocoaMQTTReader, publish: FramePublish) {
        printDebug("RECV: \(publish)")
        
        let message = CocoaMQTTMessage(topic: publish.topic, payload: publish.payload(), qos: publish.qos, retained: publish.retained)
        
        message.duplicated = publish.dup
        
        printInfo("Received message: \(message)")
        delegate?.mqtt(self, didReceiveMessage: message, id: publish.msgid)
        didReceiveMessage(self, message, publish.msgid)
        
        if message.qos == .qos1 {
            puback(FrameType.puback, msgid: publish.msgid)
        } else if message.qos == .qos2 {
            puback(FrameType.pubrec, msgid: publish.msgid)
        }
    }

    func didReceive(_ reader: CocoaMQTTReader, puback: FramePubAck) {
        printDebug("RECV: \(puback)")
        
        deliver.ack(by: puback)
        
        delegate?.mqtt(self, didPublishAck: puback.msgid)
        didPublishAck(self, puback.msgid)
    }
    
    func didReceive(_ reader: CocoaMQTTReader, pubrec: FramePubRec) {
        printDebug("RECV: \(pubrec)")
        
        deliver.ack(by: pubrec)
    }

    func didReceive(_ reader: CocoaMQTTReader, pubrel: FramePubRel) {
        printDebug("RECV: \(pubrel)")

        puback(FrameType.pubcomp, msgid: pubrel.msgid)
    }

    func didReceive(_ reader: CocoaMQTTReader, pubcomp: FramePubComp) {
        printDebug("RECV: \(pubcomp)")

        deliver.ack(by: pubcomp)
        
        delegate?.mqtt?(self, didPublishComplete: pubcomp.msgid)
        didCompletePublish(self, pubcomp.msgid)
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
        
        let success: NSMutableDictionary = NSMutableDictionary()
        var failed = [String]()
        for (idx,(topic, _)) in topicsAndQos.enumerated() {
            if suback.grantedQos[idx] != .FAILTURE {
                subscriptions[topic] = suback.grantedQos[idx]
                success[topic] = suback.grantedQos[idx].rawValue
            } else {
                failed.append(topic)
            }
        }

        delegate?.mqtt(self, didSubscribeTopics: success, failed: failed)
        didSubscribeTopics(self, success, failed)
    }

    func didReceive(_ reader: CocoaMQTTReader, unsuback: FrameUnsubAck) {
        printDebug("RECV: \(unsuback)")
        
        guard let topics = unsubscriptionsWaitingAck.removeValue(forKey: unsuback.msgid) else {
            printWarning("UNEXPECT UNSUBACK Received: \(unsuback.msgid)")
            return
        }
        // Remove local subscription
        for t in topics {
            subscriptions.removeValue(forKey: t)
        }
        delegate?.mqtt(self, didUnsubscribeTopics: topics)
        didUnsubscribeTopics(self, topics)
    }

    func didReceive(_ reader: CocoaMQTTReader, pingresp: FramePingResp) {
        printDebug("RECV: \(pingresp)")
        
        delegate?.mqttDidReceivePong(self)
        didReceivePong(self)
    }
}
