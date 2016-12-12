//
//  PreferencesWindowController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 7/14/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

class PreferencesWindowController: NSWindowController {
    
    override var windowNibName: String? {
        return "PreferencesWindowController"
    }
    
    @IBOutlet weak var numDevicesFoundTextField: NSTextField!
    var model: LIFXModel!

    override func windowDidLoad() {
        numDevicesFoundTextField.reactive.stringValue <~ model.devices.map { (devices) -> String in
            return "\(devices.count) Devices Found"
        }
    }
    
    @IBAction func searchForDevices(_ sender: NSButton) {
        model?.discover()
    }
}
