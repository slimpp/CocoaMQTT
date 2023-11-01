//
//  CocoaMQTTDeliver.swift
//  CocoaMQTT
//
//  Created by HJianBo on 2019/5/2.
//  Copyright © 2019 emqx.io. All rights reserved.
//

import Foundation
import Dispatch

protocol CocoaMQTTDeliverProtocol: AnyObject {
    
    var delegateQueue: DispatchQueue { get set }
    
    func deliver(_ deliver: CocoaMQTTDeliver, wantToSend frame: Frame)
}

private struct InflightFrame {
    
    /// The infligth frame maybe a `FramePublish` or `FramePubRel`
    var frame: Frame
    
    var timestamp: TimeInterval
    
    var retryCount: Int

    init(frame: Frame) {
        self.init(frame: frame, timestamp: Date.init(timeIntervalSinceNow: 0).timeIntervalSince1970, retryCount: 0)
    }
    
    init(frame: Frame, timestamp: TimeInterval, retryCount: Int) {
        self.frame = frame
        self.timestamp = timestamp
        self.retryCount = retryCount
    }
}

extension Array where Element == InflightFrame {
    
    func filterMap(isIncluded: (Element) -> (Bool, Element)) -> [Element] {
        var tmp = [Element]()
        for e in self {
            let res = isIncluded(e)
            if res.0 {
                tmp.append(res.1)
            }
        }
        return tmp
    }
}

// CocoaMQTTDeliver
class CocoaMQTTDeliver: NSObject {
    
    /// The dispatch queue is used by delivering frames in serially
    private var deliverQueue = DispatchQueue.init(label: "deliver.cocoamqtt.emqx", qos: .default)
    
    weak var delegate: CocoaMQTTDeliverProtocol?
    
    fileprivate var inflight = [InflightFrame]()
    
    fileprivate var mqueue = [Frame]()
    
    var mqueueSize: UInt = 1000
    
    var inflightWindowSize: UInt = 10
    
    /// Retry time interval millisecond
    var retryTimeInterval: Double = 5000
    
    private var awaitingTimer: CocoaMQTTTimer?
    
    var isQueueEmpty: Bool { get { return mqueue.count == 0 }}
    var isQueueFull: Bool { get { return mqueue.count >= mqueueSize }}
    var isInflightFull: Bool { get { return inflight.count >= inflightWindowSize }}
    var isInflightEmpty: Bool { get { return inflight.count == 0 }}
    
    var storage: CocoaMQTTStorage?
    
    func recoverSessionBy(_ storage: CocoaMQTTStorage) {
        
        let frames = storage.takeAll()
        guard frames.count >= 0 else {
            return
        }
        
        // Sync to push the frame to mqueue for avoiding overcommit
        deliverQueue.sync {
            for f in frames {
                mqueue.append(f)
            }
            self.storage = storage
            printInfo("Deliver recover \(frames.count) msgs")
            printDebug("Recover message \(frames)")
        }
        
        deliverQueue.async { [weak self] in
            guard let self = self else { return }
            self.tryTransport()
        }
    }
    
    /// Add a FramePublish to the message queue to wait for sending
    ///
    /// return false means the frame is rejected because of the buffer is full
    func add(_ frame: FramePublish) -> Bool {
        guard !isQueueFull else {
            printError("Sending buffer is full, frame \(frame) has been rejected to add.")
            return false
        }
        
        // Sync to push the frame to mqueue for avoiding overcommit
        deliverQueue.sync {
            mqueue.append(frame)
            _ = storage?.write(frame)
        }
        
        deliverQueue.async { [weak self] in
            guard let self = self else { return }
            self.tryTransport()
        }
        
        return true
    }

    /// Acknowledge a PUBLISH/PUBREL by msgid
    func ack(by frame: Frame) {
        var msgid: UInt16
        
        if let puback = frame as? FramePubAck { msgid = puback.msgid }
        else if let pubrec = frame as? FramePubRec { msgid = pubrec.msgid }
        else if let pubcom = frame as? FramePubComp { msgid = pubcom.msgid }
        else { return }
        
        deliverQueue.async { [weak self] in
            guard let self = self else { return }
            let acked = self.ackInflightFrame(withMsgid: msgid, type: frame.type)
            if acked.count == 0 {
                printWarning("Acknowledge by \(frame), but not found in inflight window")
            } else {
                // TODO: ACK DONT DELETE PUBREL
                for f in acked {
                    if frame is FramePubAck || frame is FramePubComp {
                        self.storage?.remove(f)
                    }
                }
                printDebug("Acknowledge frame id \(msgid) success, acked: \(acked)")
                self.tryTransport()
            }
        }
    }
    
    /// Clean Inflight content to prevent message blocked, when next connection established
    ///
    /// !!Warning: it's a temporary method for hotfix #221
    func cleanAll() {
        deliverQueue.sync { [weak self] in
            guard let self = self else { return }
            self.mqueue.removeAll()
            self.inflight.removeAll()
        }
    }
}

// MARK: Private Funcs
extension CocoaMQTTDeliver {
    
    // try transport a frame from mqueue to inflight
    private func tryTransport() {
        if isQueueEmpty || isInflightFull { return }
        
        // take out the earliest frame
        if mqueue.isEmpty { return }
        let frame = mqueue.remove(at: 0)
        
        deliver(frame)
        
        // keep trying after a transport
        self.tryTransport()
    }
    
    /// Try to deliver a frame
    private func deliver(_ frame: Frame) {
        if frame.qos == .qos0 {
            // Send Qos0 message, whatever the in-flight queue is full
            // TODO: A retrict deliver mode is need?
            sendfun(frame)
        } else {
            
            sendfun(frame)
            inflight.append(InflightFrame(frame: frame))
            
            // Start a retry timer for resending it if it not receive PUBACK or PUBREC
            if awaitingTimer == nil {
                awaitingTimer = CocoaMQTTTimer.every(retryTimeInterval / 1000.0, name: "awaitingTimer") { [weak self] in
                    guard let self = self else { return }
                    self.deliverQueue.async {
                        self.redeliver()
                    }
                }
            }
        }
    }
    
    /// Attempt to redeliver in-flight messages
    private func redeliver() {
        if isInflightEmpty {
            // Revoke the awaiting timer
            awaitingTimer = nil
            return
        }
        
        let nowTimestamp = Date(timeIntervalSinceNow: 0).timeIntervalSince1970
        for (idx, frame) in inflight.enumerated() {
            if (nowTimestamp - frame.timestamp) >= (retryTimeInterval/1000.0) * Double(frame.retryCount) {
                
                var duplicatedFrame = frame
                duplicatedFrame.frame.dup = true
                duplicatedFrame.retryCount += 1
                
                inflight[idx] = duplicatedFrame
                
                printInfo("Re-delivery frame \(duplicatedFrame.frame)")
                sendfun(duplicatedFrame.frame)
            }
        }
    }

    @discardableResult
    private func ackInflightFrame(withMsgid msgid: UInt16, type: FrameType) -> [Frame] {
        var ackedFrames = [Frame]()
        inflight = inflight.filterMap { frame in
            
            // -- ACK for PUBLISH
            if let publish = frame.frame as? FramePublish,
                publish.msgid == msgid {
                
                if publish.qos == .qos2 && type == .pubrec {  // -- Replace PUBLISH with PUBREL
                    let pubrel = FramePubRel(msgid: publish.msgid)
                    
                    var nframe = frame
                    nframe.frame = pubrel
                    nframe.timestamp = Date(timeIntervalSinceNow: 0).timeIntervalSince1970
                    
                    _ = storage?.write(pubrel)
                    sendfun(pubrel)
                    
                    ackedFrames.append(publish)
                    return (true, nframe)
                } else if publish.qos == .qos1 && type == .puback {
                    ackedFrames.append(publish)
                    return (false, frame)
                }
            }
            
            // -- ACK for PUBREL
            if let pubrel = frame.frame as? FramePubRel,
                pubrel.msgid == msgid && type == .pubcomp {
                
                ackedFrames.append(pubrel)
                return (false, frame)
            }
            return (true, frame)
        }
        
        return ackedFrames
    }
    
    private func sendfun(_ frame: Frame) {
        guard let delegate = self.delegate else {
            printError("The deliver delegate is nil!!! the frame will be drop: \(frame)")
            return
        }
        
        if frame.qos == .qos0 {
            if let p = frame as? FramePublish { storage?.remove(p) }
        }
        
        delegate.delegateQueue.async {
            delegate.deliver(self, wantToSend: frame)
        }
    }
}


// For tests
extension CocoaMQTTDeliver {
    
    func t_inflightFrames() -> [Frame] {
        var frames = [Frame]()
        for f in inflight {
            frames.append(f.frame)
        }
        return frames
    }
    
    func t_queuedFrames() -> [Frame] {
        return mqueue
    }
}
