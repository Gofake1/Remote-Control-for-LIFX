//
//  ColorWheel.swift
//  LIFX Remote
//
//  Created by David Wu on 11/26/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa

@IBDesignable
class ColorWheel: NSControl {
    
    struct RGBA {
        var r: UInt8
        var g: UInt8
        var b: UInt8
        var a: UInt8
        
        init() {
            self.r = 0
            self.g = 0
            self.b = 0
            self.a = 0
        }
        
        init(r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
            self.r = r
            self.g = g
            self.b = b
            self.a = a
        }
        
        init(hue: Float, saturation: Float, brightness: Float) {
            let h = hue * 6
            let s = saturation
            let v = brightness
            let i = floor(h)
            let f = h - i
            let p = v * (1.0 - s)
            let q = v * (1.0 - s * f)
            let t = v * (1.0 - s * (1.0 - f))
            var r, g, b: Float
            
            switch i {
            case 0:
                r = v
                g = t
                b = p
            case 1:
                r = q
                g = v
                b = p
            case 2:
                r = p
                g = v
                b = t
            case 3:
                r = p
                g = q
                b = v
            case 4:
                r = t
                g = p
                b = v
            default:
                r = v
                g = p
                b = q
            }
            self.r = UInt8(r*255)
            self.g = UInt8(g*255)
            self.b = UInt8(b*255)
            self.a = 255
        }
        
        init(at point: (x: Int, y: Int), origin: (x: Int, y: Int)) {
            let angle = atan2(Float(point.x - origin.x), Float(point.y - origin.y)) + Float(M_PI)
            let distance = sqrtf(powf(Float(point.x - origin.x), 2) + powf(Float(point.y - origin.y), 2))
            var hue = angle / Float(M_PI * 2)
            hue = min(hue, 1)
            hue = max(hue, 0)
            var saturation = distance / Float(origin.x) // origin.x or origin.y could be used to represent radius
            saturation = min(saturation, 1)
            saturation = max(saturation, 0)
            self.init(hue: hue, saturation: saturation, brightness: 1)
        }
    }
    
    @IBInspectable var selectedColor: NSColor = NSColor.white
    
    private func position(for color: RGBA) -> NSPoint {
        return NSPoint(x: 0, y: 0)
    }

    override func draw(_ dirtyRect: NSRect) {
        let width = Int(dirtyRect.width)
        let height = Int(dirtyRect.height)
        var imageData: [RGBA] = Array<RGBA>(repeating: RGBA(), count: width*height)
        
        for y in 0..<height {
            for x in 0..<width {
                imageData[x + y * width] = RGBA(at: (x, y), origin: (width/2, height/2))
            }
        }
        
        let radialImage = CGImage(width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bitsPerPixel: 32,
                                  bytesPerRow: width * MemoryLayout<RGBA>.size,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                                  provider: CGDataProvider(data: NSData(bytes: &imageData,
                                                                        length: imageData.count *
                                                                                MemoryLayout<RGBA>.size))!,
                                  decode: nil,
                                  shouldInterpolate: true,
                                  intent: .defaultIntent)
        
        if let radialImage = radialImage {
            NSGraphicsContext.current()?.cgContext.draw(radialImage, in: dirtyRect)
        }
        
        let circle = NSBezierPath(ovalIn: NSRect(origin: CGPoint(x: CGFloat(width)/2-5.5,
                                                                 y: CGFloat(height)/2-5.5),
                                                 size: CGSize(width: 11, height: 11)))
        circle.stroke()
        let verticalLine = NSBezierPath()
        verticalLine.move(to: NSPoint(x: CGFloat(width)/2, y: CGFloat(height)/2-8))
        verticalLine.line(to: NSPoint(x: CGFloat(width)/2, y: CGFloat(height)/2+8))
        verticalLine.stroke()
        let horizontalLine = NSBezierPath()
        horizontalLine.move(to: NSPoint(x: CGFloat(width)/2-8, y: CGFloat(height)/2))
        horizontalLine.line(to: NSPoint(x: CGFloat(width)/2+8, y: CGFloat(height)/2))
        horizontalLine.stroke()
    }
}
