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
        updateViews()
    }
    
    // Can be called by StatusMenuController
    func updateViews() {
        labelTextField.stringValue = device.label ?? "Unknown"
        brightnessSlider.isEnabled = (device.power == .enabled) ? true : false
        if let light = device as? LIFXLight {
            guard let color = light.color else { return }
            brightnessSlider.integerValue = color.brightnessAsPercentage
            lightColorView.color = NSColor(from: color)
        }
    }
    
    @IBAction func showHud(_ sender: NSClickGestureRecognizer) {
        HudController.show(device)
    }
    
    @IBAction func updateBrightness(_ sender: NSSlider) {
        if let light = device as? LIFXLight {
            guard var color = light.color else { return }
            color.brightness = UInt16(sender.doubleValue/sender.maxValue * Double(UInt16.max))
            light.setColor(color)
        }
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
