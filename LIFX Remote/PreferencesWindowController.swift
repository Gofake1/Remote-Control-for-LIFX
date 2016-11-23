//
//  PreferencesWindowController.swift
//  LIFX Remote
//
//  Created by David Wu on 7/14/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa

class PreferencesWindowController: NSWindowController {
    
    override var windowNibName: String? {
        return "PreferencesWindowController"
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
