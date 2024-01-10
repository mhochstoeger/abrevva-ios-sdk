//
//  Message.swift
//  Plugin
//
//  Created by Matthias on 08.01.24.
//  Copyright © 2024 Max Lynch. All rights reserved.
//

import Foundation

public class Message: Codable {
    
    private let t: String
    private let e: String
    private let oid: String
    private let atr: String?
    
    init(t: String, e: String, oid: String, atr: String?) {
        self.t = t
        self.e = e
        self.oid = oid
        self.atr = atr
    }
    
    func toJson() -> String? {
        do {
            let data = try JSONEncoder().encode(self)
            return String(data: data, encoding: .utf8)!
        } catch {
            print("\(error)")
            return nil
        }
    }
}

