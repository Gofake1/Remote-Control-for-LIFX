//
//  ColorWheel.swift
//  Remote Control for LIFX
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
        
        var cgColor: CGColor {
            return CGColor(red:   CGFloat(r)/CGFloat(UInt8.max),
                           green: CGFloat(g)/CGFloat(UInt8.max),
                           blue:  CGFloat(b)/CGFloat(UInt8.max),
                           alpha: CGFloat(a)/CGFloat(UInt8.max))
        }
        
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
            let angle      = atan2(Float(origin.x - point.x), Float(origin.y - point.y)) + Float(M_PI)
            let distance   = sqrtf(powf(Float(origin.x - point.x), 2) + powf(Float(origin.y - point.y), 2))
            var hue        = angle / Float(M_PI * 2)
            hue            = max(min(hue, 1), 0)
            var saturation = distance / Float(origin.x) // origin.x or origin.y could be used to represent radius
            saturation     = max(min(saturation, 1), 0)
            self.init(hue: hue, saturation: saturation, brightness: 1)
        }
    }
    
    struct HSB {
        var h: CGFloat
        var s: CGFloat
        var b: CGFloat
        
        init(r: CGFloat, g: CGFloat, b: CGFloat) {
            let minRgb = min(r, min(g, b))
            let maxRgb = max(r, max(g, b))
            if minRgb == maxRgb {
                self.h = 0
                self.s = 0
                self.b = maxRgb
            } else {
                let d: CGFloat = (r == minRgb) ? g - b : ((b == minRgb) ? r - g : b - r)
                let h: CGFloat = (r == minRgb) ? 3 : ((b == minRgb) ? 1 : 5)
                self.h = (h - d/(maxRgb - minRgb)) / 6
                self.s = (maxRgb - minRgb) / maxRgb
                self.b = maxRgb
            }
        }
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    var selectedColor: CGColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1) {
        didSet {
            needsDisplay = true
        }
    }
    //var selectedPoint: (CGFloat, CGFloat)?
    static var radialImage: CGImage?
    
    private func point(for color: CGColor, origin: (x: CGFloat, y: CGFloat)) -> (x: CGFloat, y: CGFloat)? {
        guard let components = color.components else { return nil }
        let hsb      = HSB(r: components[0], g: components[1], b: components[2])
        let angle    = (hsb.h * CGFloat(M_PI) * 2)
        let distance = hsb.s * origin.x // origin.x or origin.y could be used to represent radius
        let x = origin.x + sin(angle)*distance
        let y = origin.y - cos(angle)*distance
        return (x: x, y: y)
    }

    override func draw(_ dirtyRect: NSRect) {
        let width  = Int(dirtyRect.width)
        let height = Int(dirtyRect.height)
        
        if ColorWheel.radialImage == nil {
            var imageData: [RGBA] = Array<RGBA>(repeating: RGBA(), count: width*height)
            
            for y in 0..<height {
                for x in 0..<width {
                    imageData[x + y * width] = RGBA(at: (x, y), origin: (width/2, height/2))
                }
            }
            
            ColorWheel.radialImage = CGImage(width: width,
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
        }
        NSGraphicsContext.current()?.cgContext.draw(ColorWheel.radialImage!, in: dirtyRect)
        
        guard let point = self.point(for: selectedColor, origin: (x: CGFloat(width)/2, CGFloat(height)/2))
            else { return }
        var path = NSBezierPath(ovalIn: NSRect(x: point.x-5.5, y: point.y-5.5, width: 11, height: 11))
        path.stroke()
        path = NSBezierPath()
        path.move(to: NSPoint(x: point.x, y: point.y-8))
        path.line(to: NSPoint(x: point.x, y: point.y+8))
        path.stroke()
        path = NSBezierPath()
        path.move(to: NSPoint(x: point.x-8, y: point.y))
        path.line(to: NSPoint(x: point.x+8, y: point.y))
        path.stroke()
    }
    
    override func mouseDown(with event: NSEvent) {
        let x = event.locationInWindow.x - 5
        let y = event.locationInWindow.y - 89
        selectedColor = RGBA(at:     (x: Int(x), y: Int(y)),
                             origin: (x: Int(frame.width/2), y: Int(frame.height/2))).cgColor
        NSApp.sendAction(action!, to: target, from: self)
    }
}
