//
//  HighlightingView.swift
//  LIFX Remote
//
//  Created by David Wu on 11/14/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa

/// Main view for StatusMenuItemController
class HighlightingView: NSView {
    
    @IBOutlet weak var label: NSTextField!

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if enclosingMenuItem!.isHighlighted {
            NSColor.selectedMenuItemColor.set()
            label.textColor = NSColor.selectedMenuItemTextColor
        } else {
            NSColor.clear.set()
            label.textColor = NSColor.controlTextColor
        }
        NSRectFillUsingOperation(dirtyRect, .sourceOver)
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
}
