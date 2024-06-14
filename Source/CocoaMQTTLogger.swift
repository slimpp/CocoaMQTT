//
//  CocoaMQTTLogger.swift
//  CocoaMQTT
//
//  Created by HJianBo on 2019/5/2.
//  Copyright © 2019 emqx.io. All rights reserved.
//

import Foundation

// Convenience functions
func printDebug(_ message: String) {
    CocoaMQTTLogger.logger.debug(message)
}

func printInfo(_ message: String) {
    CocoaMQTTLogger.logger.info(message)
}

func printWarning(_ message: String) {
    CocoaMQTTLogger.logger.warning(message)
}

func printError(_ message: String) {
    CocoaMQTTLogger.logger.error(message)
}


// Enum log levels
public enum CocoaMQTTLoggerLevel: Int {
    case debug = 0, info, warning, error, off
}


open class CocoaMQTTLogger: NSObject {
    
    // Singleton
    public static var logger = CocoaMQTTLogger()
    public override init() { super.init() }

    // min level
    public var minLevel: CocoaMQTTLoggerLevel = .warning
    
    // logs
    open func log(level: CocoaMQTTLoggerLevel, message: String) {
        guard level.rawValue >= minLevel.rawValue else { return }
        print("CocoaMQTT(\(level)): \(message)")
    }
    
    func debug(_ message: String) {
        log(level: .debug, message: message)
    }
    
    func info(_ message: String) {
        log(level: .info, message: message)
    }
    
    func warning(_ message: String) {
        log(level: .warning, message: message)
    }
    
    func error(_ message: String) {
        log(level: .error, message: message)
    }
    
}
