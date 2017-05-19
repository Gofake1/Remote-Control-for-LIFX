//
//  StatusMenuItemColorView.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 11/13/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa
import ReactiveSwift

@IBDesignable
class StatusMenuItemColorView: NSView {
    
    override var allowsVibrancy: Bool {
        return true
    }
    
    var color: NSColor? {
        didSet {
            needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(ovalIn: NSRect(x:      dirtyRect.origin.x+2,
                                               y:      dirtyRect.origin.y+2,
                                               width:  dirtyRect.width-4,
                                               height: dirtyRect.height-4))
        NSColor.textColor.setStroke()
        if let c = self.color {
            c.setFill()
            path.fill()
        } else {
            NSColor.clear.setFill()
            path.stroke()
        }
    }
}

extension Reactive where Base: StatusMenuItemColorView {
    var colorValue: BindingTarget<NSColor?> {
        return BindingTarget(on: UIScheduler(), lifetime: lifetime, action: { [weak base = self.base] value in
            if let base = base {
                base.color = value
            }
        })
    }
}
