//
//  HudController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 11/13/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa

protocol HudRepresentable: class {
    var hudTitle: String { get }
}

class HudController: NSWindowController {
    weak var representable: HudRepresentable!

    override var windowNibName: NSNib.Name? {
        return NSNib.Name(rawValue: "HudController")
    }

    override func windowDidLoad() {
        window?.title = representable.hudTitle
    }
}
