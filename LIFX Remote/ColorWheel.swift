//
//  ColorWheel.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 11/26/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa
import ReactiveSwift

typealias RGB = (r: UInt8, g: UInt8, b: UInt8)

@IBDesignable
class ColorWheel: NSControl {
    
    var selectedColor = NSColor.white {
        didSet {
            needsDisplay = true
        }
    }
    static var colorWheelImage: CGImage?
    private var crosshairLocation: CGPoint! {
        didSet {
            needsDisplay = true
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        if ColorWheel.colorWheelImage == nil {
            ColorWheel.colorWheelImage = colorWheelImage(rect: frame, brightness: 1.0)
        }
        crosshairLocation = CGPoint(x: frame.width/2, y: frame.height/2)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current()?.cgContext else { return }

        context.addEllipse(in: dirtyRect)
        context.clip()
        context.draw(ColorWheel.colorWheelImage!, in: dirtyRect)
        
        context.addEllipse(in: CGRect(origin: CGPoint(x: crosshairLocation.x-5.5, y: crosshairLocation.y-5.5),
                                      size: CGSize(width: 11, height: 11)))
        context.addLines(between: [CGPoint(x: crosshairLocation.x, y: crosshairLocation.y-8),
                                   CGPoint(x: crosshairLocation.x, y: crosshairLocation.y+8)])
        context.addLines(between: [CGPoint(x: crosshairLocation.x-8, y: crosshairLocation.y),
                                   CGPoint(x: crosshairLocation.x+8, y: crosshairLocation.y)])
        context.strokePath()
    }

    private func colorWheelImage(rect: NSRect, brightness: CGFloat) -> CGImage {
        let width = Int(rect.width), height = Int(rect.height)
        var imageBytes = [RGB]()
        for j in stride(from: height, to: 0, by: -1) {
            for i in 0..<width {
                let color = NSColor(coord: (i, j), center: (width/2, height/2), brightness: brightness)
                imageBytes.append(RGB(r: UInt8(color.redComponent*255),
                                      g: UInt8(color.greenComponent*255),
                                      b: UInt8(color.blueComponent*255)))
            }
        }
        return CGImage(width: width,
                       height: height,
                       bitsPerComponent: 8,
                       bitsPerPixel: 24,
                       bytesPerRow: width * MemoryLayout<RGB>.size,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: CGDataProvider(data: NSData(bytes: &imageBytes,
                                                             length: imageBytes.count *
                                                                MemoryLayout<RGB>.size))!,
                       decode: nil,
                       shouldInterpolate: false,
                       intent: .defaultIntent)!
    }

    private func setColor(at point: CGPoint) {
        let centerX = frame.width/2
        let centerY = frame.height/2
        selectedColor = NSColor(coord:  (x: Int(point.x), y: Int(point.y)),
                                center: (x: Int(frame.width/2), y: Int(frame.height/2)),
                                brightness: 1.0)

        let vX = point.x - centerX
        let vY = point.y - centerY
        let distanceFromCenter = sqrt((vX*vX) + (vY*vY))
        let radius = frame.width/2
        if distanceFromCenter > radius {
            crosshairLocation = CGPoint(x: centerX + vX/distanceFromCenter * radius,
                                        y: centerY + vY/distanceFromCenter * radius)
        } else {
            crosshairLocation = point
        }

        NSApp.sendAction(action!, to: target, from: self)
    }

    // MARK: - Mouse
    
    override func mouseDown(with event: NSEvent) {
        setColor(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseDragged(with event: NSEvent) {
        setColor(at: convert(event.locationInWindow, from: nil))
    }
}

extension NSColor {
    convenience init(coord: (x: Int, y: Int), center: (x: Int, y: Int), brightness: CGFloat) {
        let angle      = atan2(CGFloat(center.x - coord.x), CGFloat(center.y - coord.y)) + CGFloat.pi
        let distance   = sqrt(pow(CGFloat(center.x - coord.x), 2) + pow(CGFloat(center.y - coord.y), 2))
        let hue        = max(min(angle / (CGFloat.pi * 2), 1), 0)
        let saturation = max(min(distance / CGFloat(center.x), 1), 0)
        self.init(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
    }
}

extension Reactive where Base: ColorWheel {
    var selectedColorValue: BindingTarget<NSColor> {
        return BindingTarget(on: UIScheduler(), lifetime: lifetime, action: { [weak base = self.base] value in
            if let base = base {
                base.selectedColor = value
            }
        })
    }
}
