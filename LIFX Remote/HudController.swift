//
//  HudController.swift
//  LIFX Remote
//
//  Created by David Wu on 11/13/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa

class HudController: NSWindowController {
    
    override var windowNibName: String? {
        return "HudController"
    }
    
    private var device: LIFXDevice?
    private static var openedWindows = [LIFXDevice:HudController]()

    class func show(_ device: LIFXDevice) {
        if let hudController = HudController.openedWindows[device] {
            hudController.showWindow(nil)
            return
        }
        
        let hudController = HudController()
        hudController.device = device
        hudController.window?.title = device.label
        HudController.openedWindows[device] = hudController
        hudController.showWindow(nil)
    }
    
}
