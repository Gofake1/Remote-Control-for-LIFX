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
    
    @IBOutlet weak var numDevicesFoundTextField: NSTextField!
    var model: LIFXModel?

    override func windowDidLoad() {
        numDevicesFoundTextField.stringValue = "\(model!.devices.count) Devices Found"
        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)
    }
    
    @IBAction func searchForDevices(_ sender: NSButton) {
        model?.discover()
    }
}
