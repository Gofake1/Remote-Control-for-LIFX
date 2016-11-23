//
//  HudViewController.swift
//  LIFX Remote
//
//  Created by David Wu on 11/20/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa

class HudViewController: NSViewController {
    
    override var nibName: String? {
        return "HudViewController"
    }
    
    @IBOutlet weak var labelTextField: NSTextField!
    @IBOutlet weak var powerButton: NSButton!
    var device: LIFXDevice!

    override func viewDidLoad() {
        labelTextField.stringValue = device.label
    }
    
    @IBAction func togglePower(_ sender: NSButton) {
        device.setPower(level: .enabled)
    }
}
