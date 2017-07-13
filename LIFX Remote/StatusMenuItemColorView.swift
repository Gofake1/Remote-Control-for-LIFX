//
//  StatusMenuItemColorView.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 11/13/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa

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
        } else {
            NSColor.gray.setFill()
        }
        path.fill()
    }
}
