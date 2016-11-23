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
            brightnessSlider.integerValue = light.color!.brightnessAsPercentage
            lightColorView.color = NSColor(from: light.color)
        }
    }
    
    @IBAction func showHud(_ sender: NSClickGestureRecognizer) {
        HudController.show(device)
    }
    
    @IBAction func updateBrightness(_ sender: NSSlider) {
        print("\(device.label) brightness: \(UInt16(sender.doubleValue/sender.maxValue * Double(UInt16.max)))")
        if let light = device as? LIFXLight {
            light.color!.brightness = UInt16(sender.doubleValue/sender.maxValue * Double(UInt16.max))
        }
    }
    
    @IBAction func toggleBulbState(_ sender: NSClickGestureRecognizer) {
        device.power = (device.power == .enabled) ? .standby : .enabled
    }
}

extension NSColor {
    convenience init?(from color: LIFXLight.Color?) {
        if let color = color {
            self.init(hue:        CGFloat(color.hue)/CGFloat(UInt16.max),
                      saturation: CGFloat(color.saturation)/CGFloat(UInt16.max),
                      brightness: CGFloat(color.brightness)/CGFloat(UInt16.max),
                      alpha:      1.0)
        } else {
            return nil
        }
    }
}
