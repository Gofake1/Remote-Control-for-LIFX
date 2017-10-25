//
//  UInt16+.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 10/14/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

extension UInt16 {
    init(percentage: Double) {
        self = UInt16(percentage/100.0 * Double(UInt16.max))
    }

    init(percentage: Int) {
        self.init(percentage: Double(percentage))
    }
}
