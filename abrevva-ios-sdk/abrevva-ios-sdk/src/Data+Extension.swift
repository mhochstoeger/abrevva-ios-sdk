//
//  Data+Extension.swift
//  App
//
//  Created by Matthias on 13.12.23.
//

import Foundation

extension Data {
    public func hexEncodedString() -> String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}

@objc public class Rfid: NSObject {
    @objc public func echo(_ value: String) -> String {
        print(value)
        return value
    }
}