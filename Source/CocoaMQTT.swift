//
//  CocoaMQTT.swift
//  CocoaMQTT
//
//  Created by Feng Lee<feng@eqmtt.io> on 14/8/3.
//  Copyright (c) 2015 emqx.io. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

/// Quality of Service levels
@objc public enum CocoaMQTTQoS: UInt8, CustomStringConvertible {
    /// At most once delivery
    case qos0 = 0
    
    /// At least once delivery
    case qos1
    
    /// Exactly once delivery
    case qos2
    
    /// !!! Used SUBACK frame only
    case FAILTURE = 0x80
    
    public var description: String {
        switch self {
            case .qos0: return "qos0"
            case .qos1: return "qos1"
            case .qos2: return "qos2"
            case .FAILTURE: return "Failure"
        }
    }
}

/**
 * Connection State
 */
@objc public enum CocoaMQTTConnState: UInt8, CustomStringConvertible {
    case initial = 0
    case connecting
    case connected
    case disconnected
    
    public var description: String {
        switch self {
            case .initial:      return "initial"
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

/**
 * MQTT Delegate
 */
@objc public protocol CocoaMQTTDelegate {
    /// MQTT connected with server
    // deprecated: instead of `mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck)`
    // func mqtt(_ mqtt: CocoaMQTT, didConnect host: String, port: Int)
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck)
    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16)
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16)
    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16 )
    // deprecated!!! instead of `func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopic topics: [String])`
    //func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopic topic: String)
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics topics: [String])
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String])
    func mqttDidPing(_ mqtt: CocoaMQTT)
    func mqttDidReceivePong(_ mqtt: CocoaMQTT)
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?)
    @objc optional func mqtt(_ mqtt: CocoaMQTT, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void)
    @objc optional func mqtt(_ mqtt: CocoaMQTT, didPublishComplete id: UInt16)
    @objc optional func mqtt(_ mqtt: CocoaMQTT, didStateChangeTo state: CocoaMQTTConnState)
}

/**
 * Blueprint of the MQTT client
 */
protocol CocoaMQTTClient {
    var host: String { get set }
    var port: UInt16 { get set }
    var clientID: String { get }
    var username: String? {get set}
    var password: String? {get set}
    var cleanSession: Bool {get set}
    var keepAlive: UInt16 {get set}
    var willMessage: CocoaMQTTMessage? {get set}

    func connect() -> Bool
    func connect(timeout:TimeInterval) -> Bool
    func disconnect()
    func ping()
    
    func subscribe(_ topic: String, qos: CocoaMQTTQoS) -> UInt16
    func subscribe(_ topics: [(String, CocoaMQTTQoS)]) -> UInt16
    
    func unsubscribe(_ topic: String) -> UInt16
    func publish(_ topic: String, withString string: String, qos: CocoaMQTTQoS, retained: Bool) -> UInt16
    func publish(_ message: CocoaMQTTMessage) -> UInt16
    
}


/// MQTT Client
///
/// - Note: GCDAsyncSocket need delegate to extend NSObject
public class CocoaMQTT: NSObject, CocoaMQTTClient, CocoaMQTTDeliverProtocol {
    
    public weak var delegate: CocoaMQTTDelegate?
    
    public var host = "localhost"
    public var port: UInt16 = 1883
    public var clientID: String
    public var username: String?
    public var password: String?
    public var cleanSession = true
    public var willMessage: CocoaMQTTMessage?
    public var backgroundOnSocket = true
    public var dispatchQueue = DispatchQueue.main
    
    public var connState = CocoaMQTTConnState.initial {
        didSet {
            delegate?.mqtt?(self, didStateChangeTo: connState)
            didChangeState(self, connState)
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
    /// The new publishing messages of Qos1/Qos2 will be drop, if the quene is full
    public var messageQueueSize: UInt {
        get { return deliver.mqueueSize }
        set { deliver.mqueueSize = newValue }
    }
    
    /// In-flight window size. default 10
    public var inflightWindowSize: UInt {
        get { return deliver.inflightWindowSize }
        set { deliver.inflightWindowSize = newValue }
    }
    
    /// Keep alive time inerval
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
    
    private var reconectTimeInterval: UInt16 = 0
    
    private var autoReconnTimer: CocoaMQTTTimer?
    private var disconnectExpectedly = false
    
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
    public var enableSSL = false
    
    ///
    public var sslSettings: [String: NSObject]?
    
    /// Allow self-signed ca certificate.
    ///
    /// Default is false
    public var allowUntrustCACertificate = false
    
    /// The subscribed topics in current communication
    public var subscriptions: [String: CocoaMQTTQoS] = [:]
    
    fileprivate var subscriptionsWaitingAck: [UInt16: [(String, CocoaMQTTQoS)]] = [:]
    fileprivate var unsubscriptionsWaitingAck: [UInt16: [String]] = [:]
    
    /// Sending messages
    fileprivate var sendingMessages: [UInt16: CocoaMQTTMessage] = [:]

    /// Global message id
    fileprivate var gmid: UInt16 = 1
    fileprivate var socket = GCDAsyncSocket()
    fileprivate var reader: CocoaMQTTReader?
    
    // Closures
    public var didConnectAck: (CocoaMQTT, CocoaMQTTConnAck) -> Void = { _, _ in }
    public var didPublishMessage: (CocoaMQTT, CocoaMQTTMessage, UInt16) -> Void = { _, _, _ in }
    public var didPublishAck: (CocoaMQTT, UInt16) -> Void = { _, _ in }
    public var didReceiveMessage: (CocoaMQTT, CocoaMQTTMessage, UInt16) -> Void = { _, _, _ in }
    public var didSubscribeTopics: (CocoaMQTT, [String]) -> Void = { _, _ in }
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
    public init(clientID: String, host: String = "localhost", port: UInt16 = 1883) {
        self.clientID = clientID
        self.host = host
        self.port = port
        super.init()
        deliver.delegate = self
    }
    
    deinit {
		aliveTimer?.suspend()
        autoReconnTimer?.suspend()
        
        socket.delegate = nil
        socket.disconnect()
    }
    
    // MARK: CocoaMQTTDeliverProtocol
    func deliver(_ deliver: CocoaMQTTDeliver, wantToSend frame: FramePublish) {
        let msgid = frame.msgid
        guard let message = sendingMessages[msgid] else {
            return
        }
        
        send(frame, tag: Int(msgid))
        
        delegate?.mqtt(self, didPublishMessage: message, id: msgid)
        didPublishMessage(self, message, msgid)
    }

    fileprivate func send(_ frame: Frame, tag: Int = 0) {
        let data = frame.bytes()
        socket.write(Data(bytes: data, count: data.count), withTimeout: -1, tag: tag)
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
        if gmid == UInt16.max {
            gmid = 0
        }
        gmid += 1
        return gmid
    }

    fileprivate func puback(_ type: FrameType, msgid: UInt16) {
        var frame: Frame
        switch type {
        case .puback: frame = FramePubAck(msgid: msgid)
        case .pubrec: frame = FramePubRec(msgid: msgid)
        case .pubrel: frame = FramePubRel(msgid: msgid)
        case .pubcomp: frame = FramePubComp(msgid: msgid)
        default: return
        }
        printDebug("Send \(type), msgid: \(msgid)")
        send(frame)
    }
    

    /// Connect to MQTT broker
    public func connect() -> Bool {
        return connect(timeout: -1)
    }
    
    /// Connect to MQTT broker
    public func connect(timeout: TimeInterval) -> Bool {
        socket.setDelegate(self, delegateQueue: dispatchQueue)
        reader = CocoaMQTTReader(socket: socket, delegate: self)
        do {
            if timeout > 0 {
                try socket.connect(toHost: self.host, onPort: self.port, withTimeout: timeout)
            } else {
                try socket.connect(toHost: self.host, onPort: self.port)
            }
            connState = .connecting
            return true
        } catch let error as NSError {
            printError("socket connect error: \(error.description)")
            return false
        }
    }
    
    /// Send a DISCONNECT packet to the broker then close the connection
    ///
    /// - Note: Only can be called from outside.
    ///         If you want to disconnect from inside framwork, call internal_disconnect()
    ///         disconnect expectedly
    public func disconnect() {
        disconnectExpectedly = true
        internal_disconnect()
    }
    
    /// Disconnect unexpectedly
    func internal_disconnect() {
        send(FrameDisconnect(), tag: -0xE0)
        socket.disconnect()
    }
    
    /// Send ping request to broker
    public func ping() {
        printDebug("ping")
        send(FramePingReq(), tag: -0xC0)
        self.delegate?.mqttDidPing(self)
        didPing(self)
    }
    
    
    /// Publish a message
    ///
    /// - Parameters:
    ///    - topic: Topic Name. It can not contain '#', '+' wildcards
    ///    - string: Payload string
    ///    - qos: Qos. Default is Qos1
    ///    - retained: Retained flag. Mark this message is a retained message. default is false
    @discardableResult
    public func publish(_ topic: String, withString string: String, qos: CocoaMQTTQoS = .qos1, retained: Bool = false) -> UInt16 {
        let message = CocoaMQTTMessage(topic: topic, string: string, qos: qos, retained: retained)
        return publish(message)
    }

    @discardableResult
    public func publish(_ message: CocoaMQTTMessage) -> UInt16 {
        let msgid: UInt16 = nextMessageID()
        // XXX: qos0 should not take msgid
        var frame = FramePublish(msgid: msgid, topic: message.topic, payload: message.payload)
        frame.qos = message.qos
        frame.retained = message.retained
        
        // Push frame to deliver message queue
        _ = deliver.add(frame)
        
        // XXX: For process safety
        dispatchQueue.async {
            self.sendingMessages[msgid] = message
        }
        
        return msgid
    }

    @discardableResult
    public func subscribe(_ topic: String, qos: CocoaMQTTQoS = .qos1) -> UInt16 {
        return subscribe([(topic, qos)])
    }
    
    @discardableResult
    public func subscribe(_ topics: [(String, CocoaMQTTQoS)]) -> UInt16 {
        let msgid = nextMessageID()
        let frame = FrameSubscribe(msgid: msgid, topics: topics)
        send(frame, tag: Int(msgid))
        subscriptionsWaitingAck[msgid] = topics
        return msgid
    }

    @discardableResult
    public func unsubscribe(_ topic: String) -> UInt16 {
        return unsubscribe([topic])
    }
    
    @discardableResult
    public func unsubscribe(_ topics: [String]) -> UInt16 {
        let msgid = nextMessageID()
        let frame = FrameUnsubscribe(msgid: msgid, topics: topics)
        unsubscriptionsWaitingAck[msgid] = topics
        send(frame, tag: Int(msgid))
        return msgid
    }
}

// MARK: - GCDAsyncSocketDelegate
extension CocoaMQTT: GCDAsyncSocketDelegate {
    public func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        printInfo("Connected to \(host) : \(port)")
        
        #if os(iOS)
            if backgroundOnSocket {
                sock.perform { sock.enableBackgroundingOnSocket() }
            }
        #endif
        
        if enableSSL {
            var setting = sslSettings ?? [:]
            if allowUntrustCACertificate {
                setting[GCDAsyncSocketManuallyEvaluateTrust as String] = NSNumber(value: true)
            }
            sock.startTLS(setting)
        } else {
            sendConnectFrame()
        }
    }

    public func socket(_ sock: GCDAsyncSocket, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Swift.Void) {
        printDebug("didReceiveTrust")
        
        delegate?.mqtt?(self, didReceive: trust, completionHandler: completionHandler)
        didReceiveTrust(self, trust, completionHandler)
    }

    public func socketDidSecure(_ sock: GCDAsyncSocket) {
        printDebug("socketDidSecure")
        sendConnectFrame()
    }

    public func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        printDebug("Socket write message with tag: \(tag)")
    }

    public func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
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

    public func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        // Clean up
        socket.delegate = nil
        connState = .disconnected
        delegate?.mqttDidDisconnect(self, withError: err)
        didDisconnect(self, err)
        
        if disconnectExpectedly {
            connState = .initial
        } else if autoReconnect {
            if reconectTimeInterval == 0 {
                reconectTimeInterval = autoReconnectTimeInterval
            }
            
            // Start reconnector once socket error occuried
            printInfo("Try reconnect to server after \(reconectTimeInterval)s")
            autoReconnTimer = CocoaMQTTTimer.after(Double(reconectTimeInterval), { [weak self] in
                guard let self = self else { return }
                if self.reconectTimeInterval < self.maxAutoReconnectTimeInterval {
                    self.reconectTimeInterval *= 2
                } else {
                    self.reconectTimeInterval = self.maxAutoReconnectTimeInterval
                }
                _ = self.connect()
            })
        }
    }
}

// MARK: - CocoaMQTTReaderDelegate
extension CocoaMQTT: CocoaMQTTReaderDelegate {
    
    func didReceiveConnAck(_ reader: CocoaMQTTReader, connack: UInt8) {
        printDebug("CONNACK Received: \(connack)")

        let ack: CocoaMQTTConnAck
        switch connack {
        case 0:
            ack = .accept
            connState = .connected
        case 1...5:
            ack = CocoaMQTTConnAck(rawValue: connack)!
            internal_disconnect()
        case _ where connack > 5:
            ack = .reserved
            internal_disconnect()
        default:
            internal_disconnect()
            return
        }

        // TODO: how to handle the cleanSession = false & auto-reconnect
        if cleanSession {
            deliver.cleanAll()
        }

        delegate?.mqtt(self, didConnectAck: ack)
        didConnectAck(self, ack)
        
        // reset auto-reconnect state
        if ack == CocoaMQTTConnAck.accept {
            reconectTimeInterval = 0
            autoReconnTimer = nil
            disconnectExpectedly = false
        }
        
        // keep alive
        if ack == CocoaMQTTConnAck.accept {
            let interval = Double(keepAlive <= 0 ? 60: keepAlive)
            aliveTimer = CocoaMQTTTimer.every(interval) { [weak self] in
                guard let wself = self else {return}
                if wself.connState == .connected {
                    wself.ping()
                } else {
                    wself.aliveTimer = nil
                }
            }
        }
    }

    func didReceive(_ reader: CocoaMQTTReader, publish: FramePublish) {
        printDebug("PUBLISH Received: \(publish)")
        let message = CocoaMQTTMessage(topic: publish.topic, payload: publish.payload(), qos: publish.qos, retained: publish.retained)
        
        message.duplicated = publish.dup
        
        printInfo("Recevied message: \(message)")
        delegate?.mqtt(self, didReceiveMessage: message, id: publish.msgid)
        didReceiveMessage(self, message, publish.msgid)
        
        if message.qos == CocoaMQTTQoS.qos1 {
            puback(FrameType.puback, msgid: publish.msgid)
        } else if message.qos == CocoaMQTTQoS.qos2 {
            puback(FrameType.pubrec, msgid: publish.msgid)
        }
    }

    func didReceivePubAck(_ reader: CocoaMQTTReader, msgid: UInt16) {
        printDebug("PUBACK Received: \(msgid)")
        
        deliver.sendSuccess(withMsgid: msgid)
        delegate?.mqtt(self, didPublishAck: msgid)
        didPublishAck(self, msgid)
    }
    
    func didReceivePubRec(_ reader: CocoaMQTTReader, msgid: UInt16) {
        printDebug("PUBREC Received: \(msgid)")

        puback(FrameType.pubrel, msgid: msgid)
    }

    func didReceivePubRel(_ reader: CocoaMQTTReader, msgid: UInt16) {
        printDebug("PUBREL Received: \(msgid)")

        puback(FrameType.pubcomp, msgid: msgid)
    }

    func didReceivePubComp(_ reader: CocoaMQTTReader, msgid: UInt16) {
        printDebug("PUBCOMP Received: \(msgid)")

        deliver.sendSuccess(withMsgid: msgid)
        delegate?.mqtt?(self, didPublishComplete: msgid)
        didCompletePublish(self, msgid)
    }

    func didReceiveSubAck(_ reader: CocoaMQTTReader, suback: FrameSubAck) {
        printDebug("SUBACK Received: \(suback.msgid)")
        
        guard let topicsAndQos = subscriptionsWaitingAck.removeValue(forKey: suback.msgid) else {
            printWarning("UNEXPECT SUBACK Received: \(suback)")
            return
        }
        
        guard topicsAndQos.count == suback.grantedQos.count else {
            printWarning("UNEXPECT SUBACK Recivied: \(suback)")
            return
        }
        
        var topics: [String] = []
        for (idx,(topic, _)) in topicsAndQos.enumerated() {
            if suback.grantedQos[idx] != .FAILTURE {
                subscriptions[topic] = suback.grantedQos[idx]
                topics.append(topic)
            }
        }
        
        delegate?.mqtt(self, didSubscribeTopics: topics)
        didSubscribeTopics(self, topics)
    }

    func didReceiveUnsubAck(_ reader: CocoaMQTTReader, msgid: UInt16) {
        printDebug("UNSUBACK Received: \(msgid)")
        
        guard let topics = unsubscriptionsWaitingAck.removeValue(forKey: msgid) else {
            printWarning("UNEXPECT UNSUBACK Received: \(msgid)")
            return
        }
        // Remove local subscription
        for t in topics {
            subscriptions.removeValue(forKey: t)
        }
        delegate?.mqtt(self, didUnsubscribeTopics: topics)
        didUnsubscribeTopics(self, topics)
    }

    func didReceivePong(_ reader: CocoaMQTTReader) {
        printDebug("PONG Received")

        delegate?.mqttDidReceivePong(self)
        didReceivePong(self)
    }
}
