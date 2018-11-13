//
//  Common+AppKit.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 7/10/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import AppKit

extension NSColor {
    // Workaround: `NSColor`'s `brightnessComponent` is sometimes a value in [0-255] instead of in [0-1]
    /// Brightness value scaled between 0 and 1
    var scaledBrightness: CGFloat {
        if brightnessComponent > 1.0 {
            return brightnessComponent/255.0
        } else {
            return brightnessComponent
        }
    }
    
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

    convenience init(coord: (x: Int, y: Int), center: (x: Int, y: Int), brightness: CGFloat) {
        let angle      = atan2(CGFloat(center.x - coord.x), CGFloat(center.y - coord.y)) + CGFloat.pi
        let distance   = sqrt(pow(CGFloat(center.x - coord.x), 2) + pow(CGFloat(center.y - coord.y), 2))
        self.init(hue:        max(min(angle / (CGFloat.pi * 2), 1), 0),
                  saturation: max(min(distance / CGFloat(center.x), 1), 0),
                  brightness: brightness,
                  alpha:      1.0)
    }
}
