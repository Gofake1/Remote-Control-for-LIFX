//
//  Common.swift
//  Remote Control for LIFX
//
//  Created by David on 3/31/18.
//  Copyright © 2018 Gofake1. All rights reserved.
//

import Darwin

extension Int32 {
    var strerror: String {
        return String(validatingUTF8: Darwin.strerror(self))!
    }
}

extension UInt16 {
    init(percentage: Double) {
        self = UInt16(percentage/100.0 * Double(UInt16.max))
    }
    
    init(percentage: Int) {
        self.init(percentage: Double(percentage))
    }
}
