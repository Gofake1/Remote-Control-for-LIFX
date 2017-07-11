//
//  NSColor+.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 7/10/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa

extension NSColor {
    convenience init?(from color: LIFXLight.Color?) {
        if let color = color {
            self.init(hue:        CGFloat(color.hue)        / CGFloat(UInt16.max),
                      saturation: CGFloat(color.saturation) / CGFloat(UInt16.max),
                      brightness: CGFloat(color.brightness) / CGFloat(UInt16.max),
                      alpha:      1.0)
        } else {
            return nil
        }
    }
}
