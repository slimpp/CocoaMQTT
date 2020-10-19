//
//  CocoaMQTTNetworkConnectionSocket.swift
//  CocoaMQTT
//
//  Created by Arthur Kao on 2020/10/12.
//  Copyright © 2020 emqx.io. All rights reserved.
//

#if canImport(Network)
import Foundation
import Network

// MARK: - CocoaMQTTNetworkConnectionSocket

@available(OSX 10.14, iOS 12.0, watchOS 6.0, tvOS 12.0, *)
public class CocoaMQTTNetworkConnectionSocket: NSObject {
    
    public var enableSSL = false

    ///
    public var sslSettings: [String: NSObject]?

    /// Allow self-signed ca certificate.
    ///
    /// Default is false
    public var allowUntrustCACertificate = false

    fileprivate var reference: NWConnection?
    fileprivate weak var delegate: CocoaMQTTSocketDelegate?
    fileprivate var delegateQueue: DispatchQueue?

    public override init() { super.init() }
}

@available(OSX 10.14, iOS 12.0, watchOS 6.0, tvOS 12.0, *)
extension CocoaMQTTNetworkConnectionSocket: CocoaMQTTSocketProtocol {
    public func setDelegate(_ theDelegate: CocoaMQTTSocketDelegate?, delegateQueue: DispatchQueue?) {
        delegate = theDelegate
        self.delegateQueue = delegateQueue
    }

    public func connect(toHost host: String, onPort port: UInt16) throws {
        try connect(toHost: host, onPort: port, withTimeout: -1)
    }

    public func connect(toHost host: String, onPort port: UInt16, withTimeout timeout: TimeInterval) throws {
        let reference = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: enableSSL ? createTLSParameters(allowInsecure: allowUntrustCACertificate, queue: delegateQueue ?? .main) : .tcp)
        self.reference = reference
        reference.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.delegate?.socketConnected(self)
            case .failed(let error):
                self.delegate?.socketDidDisconnect(self, withError: error)
            case .cancelled:
                self.delegate?.socketDidDisconnect(self, withError: nil)
            default:
                break
            }
        }
        reference.start(queue: delegateQueue ?? .main)
    }

    public func disconnect() {
        reference?.cancel()
    }

    public func readData(toLength length: UInt, withTimeout timeout: TimeInterval, tag: Int) {
        reference?.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { (data, ctx, b, errpr) in
            guard let data = data else { return }
            self.delegate?.socket(self, didRead: data, withTag: tag)
        }
    }

    public func write(_ data: Data, withTimeout timeout: TimeInterval, tag: Int) {
        let completion = NWConnection.SendCompletion.contentProcessed { (error) in
            if let error = error {
                self.delegate?.socketDidDisconnect(self, withError: error)
            } else {
                self.delegate?.socket(self, didWriteDataWithTag: tag)
            }
        }
        reference?.send(content: data, completion: completion)
    }
}

@available(OSX 10.14, iOS 12.0, watchOS 6.0, tvOS 12.0, *)
extension CocoaMQTTNetworkConnectionSocket {
    func createTLSParameters(allowInsecure: Bool, queue: DispatchQueue) -> NWParameters {
        let options = NWProtocolTLS.Options()
        if allowInsecure {
            sec_protocol_options_set_verify_block(options.securityProtocolOptions, { (sec_protocol_metadata, sec_trust, sec_protocol_verify_complete) in
                let trust = sec_trust_copy_ref(sec_trust).takeRetainedValue()
                var error: CFError?
                if SecTrustEvaluateWithError(trust, &error) {
                    sec_protocol_verify_complete(true)
                } else {
                    self.delegate?.socket(self, didReceive: trust, completionHandler: sec_protocol_verify_complete)
                }
            }, queue)
        }
        if let certificates = sslSettings?[(kCFStreamSSLCertificates as String)] as? NSArray {
            certificates.compactMap { sec_identity_create($0 as! SecIdentity) }.forEach { secIdentity in
                sec_protocol_options_set_local_identity(options.securityProtocolOptions, secIdentity)
            }
        }
        return NWParameters(tls: options)
    }
}
#endif
