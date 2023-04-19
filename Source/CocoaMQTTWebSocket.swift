//
//  CocoaMQTTWebSocket.swift
//  CocoaMQTT
//
//  Created by Cyrus Ingraham on 12/13/19.
//

import Foundation
import Starscream
#if IS_SWIFT_PACKAGE
import CocoaMQTT
#endif

// MARK: - Interfaces

public protocol CocoaMQTTWebSocketConnectionDelegate: AnyObject {
    func connection(_ conn: CocoaMQTTWebSocketConnection, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Swift.Void)

    func urlSessionConnection(_ conn: CocoaMQTTWebSocketConnection, didReceiveTrust trust: SecTrust, didReceiveChallenge challenge: URLAuthenticationChallenge,
                              completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)

    func connectionOpened(_ conn: CocoaMQTTWebSocketConnection)

    func connectionClosed(_ conn: CocoaMQTTWebSocketConnection, withError error: Error?)

    func connection(_ conn: CocoaMQTTWebSocketConnection, receivedString string: String)

    func connection(_ conn: CocoaMQTTWebSocketConnection, receivedData data: Data)
}

public protocol CocoaMQTTWebSocketConnection: NSObjectProtocol {
    var delegate: CocoaMQTTWebSocketConnectionDelegate? { get set }

    var queue: DispatchQueue { get set }

    func connect()

    func disconnect()

    func write(data: Data, handler: @escaping (Error?) -> Void)
}

public protocol CocoaMQTTWebSocketConnectionBuilder {
    func buildConnection(forURL url: URL, withHeaders headers: [String: String]) throws -> CocoaMQTTWebSocketConnection
}

// MARK: - CocoaMQTTWebSocket

public class CocoaMQTTWebSocket: CocoaMQTTSocketProtocol {
    public var enableSSL = false

    public var shouldConnectWithURIOnly = false

    public var headers: [String: String] = [:]

    public typealias ConnectionBuilder = CocoaMQTTWebSocketConnectionBuilder

    public struct DefaultConnectionBuilder: ConnectionBuilder {
        public init() {}

        public func buildConnection(forURL url: URL, withHeaders headers: [String: String]) throws -> CocoaMQTTWebSocketConnection {
            if #available(OSX 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) {
                let config = URLSessionConfiguration.default
                config.httpAdditionalHeaders = headers
                return CocoaMQTTWebSocket.FoundationConnection(url: url, config: config)
            } else {
                var request = URLRequest(url: url)
                headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
                return CocoaMQTTWebSocket.StarscreamConnection(request: request)
            }
        }
    }

    public func setDelegate(_ theDelegate: CocoaMQTTSocketDelegate?, delegateQueue: DispatchQueue?) {
        internalQueue.async {
            self.delegate = theDelegate
            self.delegateQueue = delegateQueue
        }
    }

    let uri: String
    let builder: ConnectionBuilder

    public init(uri: String = "", builder: ConnectionBuilder = CocoaMQTTWebSocket.DefaultConnectionBuilder()) {
        self.uri = uri
        self.builder = builder
    }

    public func connect(toHost host: String, onPort port: UInt16) throws {
        try connect(toHost: host, onPort: port, withTimeout: -1)
    }

    public func connect(toHost host: String, onPort port: UInt16, withTimeout timeout: TimeInterval) throws {
        var urlStr = ""

        if shouldConnectWithURIOnly {
            urlStr = "\(uri)"
        } else {
            urlStr = "\(enableSSL ? "wss" : "ws")://\(host):\(port)\(uri)"
        }

        guard let url = URL(string: urlStr) else { throw CocoaMQTTError.invalidURL }
        try internalQueue.sync {
            connection?.disconnect()
            connection?.delegate = nil
            let newConnection = try builder.buildConnection(forURL: url, withHeaders: self.headers)
            connection = newConnection
            newConnection.delegate = self
            newConnection.queue = internalQueue
            newConnection.connect()
        }
    }

    public func disconnect() {
        internalQueue.async {
            // self.reset()
            self.closeConnection(withError: nil)
        }
    }

    public func readData(toLength length: UInt, withTimeout timeout: TimeInterval, tag: Int) {
        internalQueue.async {
            let newRead = ReadItem(tag: tag, length: length, timeout: (timeout > 0.0) ? .now() + timeout : .distantFuture)
            self.scheduledReads.append(newRead)
            self.checkScheduledReads()
        }
    }

    public func write(_ data: Data, withTimeout timeout: TimeInterval, tag: Int) {
        internalQueue.async {
            let newWrite = WriteItem(tag: tag, timeout: (timeout > 0.0) ? .now() + timeout : .distantFuture)
            self.scheduledWrites.insert(newWrite)
            self.checkScheduledWrites()
            self.connection?.write(data: data) { possibleError in
                if let error = possibleError {
                    self.closeConnection(withError: error)
                } else {
                    guard self.scheduledWrites.remove(newWrite) != nil else { return }
                    guard let delegate = self.delegate else { return }
                    delegate.socket(self, didWriteDataWithTag: tag)
                }
            }
        }
    }

    internal var delegate: CocoaMQTTSocketDelegate?
    internal var delegateQueue: DispatchQueue?
    internal var internalQueue = DispatchQueue(label: "CocoaMQTTWebSocket")

    private var connection: CocoaMQTTWebSocketConnection?

    private func reset() {
        connection?.delegate = nil
        connection?.disconnect()
        connection = nil

        readBuffer.removeAll()
        scheduledReads.removeAll()
        readTimeoutTimer.reset()

        scheduledWrites.removeAll()
        writeTimeoutTimer.reset()
    }

    private func closeConnection(withError error: Error?) {
        reset()
        executeOnDelegateQueue {
            self.delegate?.socketDidDisconnect(self, withError: error)
        }
    }

    private class ReusableTimer {
        let queue: DispatchQueue
        var timer: DispatchSourceTimer?

        init(queue: DispatchQueue) {
            self.queue = queue
        }

        func schedule(wallDeadline: DispatchWallTime, handler: @escaping () -> Void) {
            reset()
            let newTimer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
            timer = newTimer
            newTimer.schedule(wallDeadline: wallDeadline)
            newTimer.setEventHandler(handler: handler)
            newTimer.resume()
        }

        func reset() {
            if timer != nil {
                timer?.cancel()
                timer = nil
            }
        }
    }

    private struct ReadItem {
        let tag: Int
        let length: UInt
        let timeout: DispatchWallTime
    }

    private var readBuffer = Data()
    private var scheduledReads: [ReadItem] = []
    private lazy var readTimeoutTimer = ReusableTimer(queue: internalQueue)

    private func checkScheduledReads() {
        guard let theDelegate = delegate else { return }
        guard let delegateQueue = delegateQueue else { return }

        readTimeoutTimer.reset()
        while (scheduledReads.first?.length ?? UInt.max) <= readBuffer.count {
            let nextRead = scheduledReads.removeFirst()
            let readRange = readBuffer.startIndex..<Data.Index(nextRead.length)
            let readData = readBuffer.subdata(in: readRange)
            readBuffer.removeSubrange(readRange)
            delegateQueue.async {
                theDelegate.socket(self, didRead: readData, withTag: nextRead.tag)
            }
        }

        guard let closestTimeout = scheduledReads.sorted(by: { a, b in a.timeout < b.timeout }).first?.timeout else { return }

        if closestTimeout < .now() {
            closeConnection(withError: CocoaMQTTError.readTimeout)
        } else {
            readTimeoutTimer.schedule(wallDeadline: closestTimeout) { [weak self] in
                self?.checkScheduledReads()
            }
        }
    }

    private struct WriteItem: Hashable {
        let uuid = UUID()
        let tag: Int
        let timeout: DispatchWallTime

        func hash(into hasher: inout Hasher) {
            hasher.combine(uuid)
        }
    }

    private var scheduledWrites = Set<WriteItem>()
    private lazy var writeTimeoutTimer = ReusableTimer(queue: internalQueue)

    private func checkScheduledWrites() {
        writeTimeoutTimer.reset()
        guard let closestTimeout = scheduledWrites.sorted(by: { a, b in a.timeout < b.timeout }).first?.timeout else { return }
        if closestTimeout < .now() {
            closeConnection(withError: CocoaMQTTError.writeTimeout)
        } else {
            writeTimeoutTimer.schedule(wallDeadline: closestTimeout) { [weak self] in
                self?.checkScheduledWrites()
            }
        }
    }
}

extension CocoaMQTTWebSocket: CocoaMQTTWebSocketConnectionDelegate {
    public func urlSessionConnection(_ conn: CocoaMQTTWebSocketConnection, didReceiveTrust trust: SecTrust,
                                     didReceiveChallenge challenge: URLAuthenticationChallenge,
                                     completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let del = delegate {
            executeOnDelegateQueue {
                del.socketUrlSession(self, didReceiveTrust: trust, didReceiveChallenge: challenge, completionHandler: completionHandler)
            }
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    public func connection(_ conn: CocoaMQTTWebSocketConnection, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        if let del = delegate {
            executeOnDelegateQueue {
                del.socket(self, didReceive: trust, completionHandler: completionHandler)
            }
        } else {
            completionHandler(false)
        }
    }

    public func connectionOpened(_ conn: CocoaMQTTWebSocketConnection) {
        guard conn.isEqual(connection) else { return }
        guard let delegate = delegate else { return }
        guard let delegateQueue = delegateQueue else { return }
        delegateQueue.async {
            delegate.socketConnected(self)
        }
    }

    public func connectionClosed(_ conn: CocoaMQTTWebSocketConnection, withError error: Error?) {
        guard conn.isEqual(connection) else { return }
        closeConnection(withError: error)
    }

    public func connection(_ conn: CocoaMQTTWebSocketConnection, receivedString string: String) {
        guard let data = string.data(using: .utf8) else { return }
        self.connection(conn, receivedData: data)
    }

    public func connection(_ conn: CocoaMQTTWebSocketConnection, receivedData data: Data) {
        guard conn.isEqual(connection) else { return }
        readBuffer.append(data)
        checkScheduledReads()
    }
}

// MARK: - CocoaMQTTWebSocket.FoundationConnection

@available(OSX 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public extension CocoaMQTTWebSocket {
    class FoundationConnection: NSObject, CocoaMQTTWebSocketConnection {
        public weak var delegate: CocoaMQTTWebSocketConnectionDelegate?
        public lazy var queue = DispatchQueue(label: "CocoaMQTTFoundationWebSocketConnection-\(self.hashValue)")

        var session: URLSession?
        var task: URLSessionWebSocketTask?

        public init(url: URL, config: URLSessionConfiguration) {
            super.init()
            let theSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            session = theSession
            task = theSession.webSocketTask(with: url, protocols: ["mqtt"])
        }

        public func connect() {
            task?.resume()
            scheduleRead()
        }

        public func disconnect() {
            task?.cancel()
            session = nil
            task = nil
            delegate = nil
        }

        public func write(data: Data, handler: @escaping (Error?) -> Void) {
            task?.send(.data(data)) { possibleError in
                self.queue.async {
                    handler(possibleError)
                }
            }
        }

        func scheduleRead() {
            queue.async {
                guard let task = self.task else { return }
                task.receive { result in
                    self.queue.async {
                        guard let delegate = self.delegate else { return }
                        switch result {
                        case .success(let message):
                            switch message {
                            case .data(let data):
                                delegate.connection(self, receivedData: data)
                            case .string(let string):
                                delegate.connection(self, receivedString: string)
                            @unknown default: break
                            }
                            self.scheduleRead()
                        case .failure(let error):
                            delegate.connectionClosed(self, withError: error)
                        }
                    }
                }
            }
        }
    }
}

@available(OSX 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension CocoaMQTTWebSocket.FoundationConnection: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, task: URLSessionTask,
                           didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        queue.async {
            if let trust = challenge.protectionSpace.serverTrust, let delegate = self.delegate {
                delegate.connection(self, didReceive: trust) { shouldTrust in
                    completionHandler(shouldTrust ? .performDefaultHandling : .rejectProtectionSpace, nil)
                }
                delegate.urlSessionConnection(self, didReceiveTrust: trust, didReceiveChallenge: challenge, completionHandler: completionHandler)
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        queue.async {
            self.delegate?.connectionOpened(self)
        }
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                           didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        queue.async {
            self.delegate?.connectionClosed(self, withError: CocoaMQTTError.FoundationConnection.closed(closeCode))
        }
    }
}

// MARK: - CocoaMQTTWebSocket.StarscreamConnection

public extension CocoaMQTTWebSocket {
    class StarscreamConnection: NSObject, CocoaMQTTWebSocketConnection {
        public var reference: WebSocket
        public weak var delegate: CocoaMQTTWebSocketConnectionDelegate?
        public var queue: DispatchQueue {
            get { reference.callbackQueue }
            set { reference.callbackQueue = newValue }
        }

        public init(request: URLRequest) {
            reference = WebSocket(request: request, protocols: ["mqtt"], stream: FoundationStream())
            super.init()
            reference.delegate = self
        }

        public func connect() {
            reference.connect()
        }

        public func disconnect() {
            reference.disconnect()
        }

        public func write(data: Data, handler: @escaping (Error?) -> Void) {
            reference.write(data: data) {
                handler(nil)
            }
        }
    }
}

extension CocoaMQTTWebSocket.StarscreamConnection: SSLTrustValidator {
    public func isValid(_ trust: SecTrust, domain: String?) -> Bool {
        guard let delegate = self.delegate else { return false }

        var shouldAccept = false
        let semaphore = DispatchSemaphore(value: 0)
        delegate.connection(self, didReceive: trust) { result in
            shouldAccept = result
            semaphore.signal()
        }
        semaphore.wait()

        return shouldAccept
    }
}

extension CocoaMQTTWebSocket.StarscreamConnection: WebSocketDelegate {
    public func websocketDidConnect(socket: WebSocketClient) {
        delegate?.connectionOpened(self)
    }

    public func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        delegate?.connectionClosed(self, withError: error)
    }

    public func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        delegate?.connection(self, receivedString: text)
    }

    public func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        delegate?.connection(self, receivedData: data)
    }
}

// MARK: - Helper

extension CocoaMQTTWebSocket {
    func executeOnDelegateQueue(_ fun: @escaping () -> Void) {
        delegateQueue?.async { [weak self] in
            guard self != nil else { return }
            fun()
        }
    }
}
