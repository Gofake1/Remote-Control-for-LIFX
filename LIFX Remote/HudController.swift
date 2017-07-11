//
//  HudController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 11/13/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa

class HudController: NSWindowController {
    
    override var windowNibName: NSNib.Name? {
        return NSNib.Name(rawValue: "HudController")
    }
    
    private static var deviceWindows = [LIFXDevice: HudController]()
    private static var groupWindows = [LIFXGroup: HudController]()

    class func show(_ device: LIFXDevice) {
        if let existingHudController = deviceWindows[device] {
            existingHudController.showWindow(nil)
        } else {
            let hudController = HudController()
            let viewController = DeviceHudViewController()
            viewController.device = device
            hudController.contentViewController = viewController
            hudController.window?.title = device.label ?? "Unknown"
            HudController.deviceWindows[device] = hudController
            hudController.showWindow(nil)
        }
    }

    class func show(_ group: LIFXGroup) {
        if let existingHudController = groupWindows[group] {
            existingHudController.showWindow(nil)
        } else {
            let hudController = HudController()
            let viewController = GroupHudViewController()
            viewController.group = group
            hudController.contentViewController = viewController
            hudController.window?.title = group.name
            HudController.groupWindows[group] = hudController
            hudController.showWindow(nil)
        }
    }

    class func reset() {
        HudController.deviceWindows = [:]
        HudController.groupWindows = [:]
    }

    class func removeGroup(_ group: LIFXGroup) {
        HudController.groupWindows[group] = nil
    }
}
