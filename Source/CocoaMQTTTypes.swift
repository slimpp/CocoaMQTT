//
//  CocoaMQTTTypes.swift
//  CocoaMQTT
//
//  Created by HJianBo on 2019/6/9.
//  Copyright © 2019 emqx.io. All rights reserved.
//

import Foundation

/// Encode and Decode big-endian UInt16
extension UInt16 {
    /// Most Significant Byte (MSB)
    private var highByte: UInt8 {
        return UInt8( (self & 0xFF00) >> 8)
    }

    /// Least Significant Byte (LSB)
    private var lowByte: UInt8 {
        return UInt8(self & 0x00FF)
    }

    var hlBytes: [UInt8] {
        return [highByte, lowByte]
    }
}

extension String {
    /// String with two bytes length
    var bytesWithLength: [UInt8] {
        return UInt16(utf8.count).hlBytes + utf8
    }

    var stringUTF8: String {
        let data = self.data(using: .nonLossyASCII)
        return String(data: data!, encoding: .utf8) ?? ""
    }
}

extension Bool {
    /// Bool to bit of UInt8
    var bit: UInt8 {
        return self ? 1 : 0
    }

    /// Initial a bool with a bit
    init(bit: UInt8) {
        self = (bit == 0) ? false : true
    }
}

extension UInt8 {
    /// Read a bit value
    func bitAt(_ offset: UInt8) -> UInt8 {
        return (self >> offset) & 0x01
    }
}

public enum CocoaMQTTError: Error {
    case invalidURL
    case readTimeout
    case writeTimeout
    @available(OSX 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public enum FoundationConnection: Error {
        case closed(URLSessionWebSocketTask.CloseCode)
    }
}

extension Array where Element == UInt8 {
    var summary: String {
        if self.count <= 10 {
            return "\(self)"
        } else {
            var descr = "[\(self[0])"
            for i in self[1..<10] {
                descr += ", \(i)"
            }
            return "\(descr), ...]"
        }
    }
}

extension Data {
    var uint8: UInt8 {
        var number: UInt8 = 0
        self.copyBytes(to: &number, count: MemoryLayout<UInt8>.size)
        return number
    }

    var uint16: UInt16 {
        let i16array = self.withUnsafeBytes { $0.load(as: UInt16.self) }
        return i16array
    }

    var uint32: UInt32 {
        let i32array = self.withUnsafeBytes { $0.load(as: UInt32.self) }
        return i32array
    }

    var uuid: NSUUID? {
        var bytes = [UInt8](repeating: 0, count: self.count)
        self.copyBytes(to: &bytes, count: self.count * MemoryLayout<UInt32>.size)
        return NSUUID(uuidBytes: bytes)
    }
    var stringASCII: String? {
        return NSString(data: self, encoding: String.Encoding.ascii.rawValue) as String?
    }

    var stringUTF8: String? {
        return NSString(data: self, encoding: String.Encoding.utf8.rawValue) as String?
    }

    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
}

extension Int {
    var data: Data {
        var int = self
        return Data(bytes: &int, count: MemoryLayout<Int>.size)
    }
}

extension UInt8 {
    var data: Data {
        var int = self
        return Data(bytes: &int, count: MemoryLayout<UInt8>.size)
    }
}

extension UInt16 {
    var data: Data {
        var int = self
        return Data(bytes: &int, count: MemoryLayout<UInt16>.size)
    }
}

extension UInt32 {
    var data: Data {
        var int = self
        return Data(bytes: &int, count: MemoryLayout<UInt32>.size)
    }

    var byteArrayLittleEndian: [UInt8] {
        return [
            UInt8((self & 0xFF000000) >> 24),
            UInt8((self & 0x00FF0000) >> 16),
            UInt8((self & 0x0000FF00) >> 8),
            UInt8(self & 0x000000FF)
        ]
    }
}
