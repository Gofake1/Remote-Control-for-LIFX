//
//  HudController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 11/13/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa

class HudController: NSWindowController {
    
    override var windowNibName: String? {
        return "HudController"
    }
    
    private var item: Either<LIFXGroup, LIFXDevice>?
    private static var openedWindows = [AnyHashable:HudController]()
    
    override func windowDidLoad() {
        guard let item = item else { return }
        switch item {
        case .left(let group):
            let hudViewController = HudGroupViewController()
            hudViewController.group = group
            window?.contentViewController = hudViewController
            
        case .right(let device):
            let hudViewController = HudDeviceViewController()
            hudViewController.device = device
            window?.contentViewController = hudViewController
        }
    }

    class func show(_ item: Either<LIFXGroup, LIFXDevice>) {
        var hashable: AnyHashable
        var title: String

        switch item {
        case .left(let group):
            if let HudController = HudController.openedWindows[group] {
                HudController.showWindow(nil)
                return
            }
            hashable = group
            title = group.name.value

        case .right(let device):
            if let hudController = HudController.openedWindows[device] {
                hudController.showWindow(nil)
                return
            }
            hashable = device
            title = device.label.value ?? "Unknown"
        }

        let hudController = HudController()
        hudController.item = item
        hudController.window?.title = title
        HudController.openedWindows[hashable] = hudController
        hudController.showWindow(nil)
    }

    class func reset() {
        HudController.openedWindows = [:]
    }

    class func removeGroup(_ group: LIFXGroup) {
        HudController.openedWindows[group] = nil
    }
}
