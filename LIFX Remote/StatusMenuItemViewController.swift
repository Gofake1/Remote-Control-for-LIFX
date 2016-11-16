//
//  StatusMenuItemViewController.swift
//  LIFX Remote
//
//  Created by David Wu on 11/13/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa

class StatusMenuItemViewController: NSViewController {
    
    override var nibName: String? {
        return "StatusMenuItemViewController"
    }
    
    @IBOutlet weak var labelTextField: NSTextField!
    @IBOutlet weak var brightnessSlider: NSSlider!
    @IBOutlet weak var lightColorView: StatusMenuColorView!
    var device: LIFXDevice!
    
    override func viewDidLoad() {
        labelTextField.stringValue = device.label
        if let light = device as? LIFXLight {
            //brightnessSlider.integerValue = device.brightness
            lightColorView.color = NSColor(from: light.color)
        }
    }
    
    @IBAction func showHud(_ sender: NSClickGestureRecognizer) {
        HudController.show(device)
    }
    
    @IBAction func updateBrightness(_ sender: NSSlider) {
        print("\(device.label): \(sender.integerValue)")
        //device.brightness = sender.integerValue
    }
    
}
