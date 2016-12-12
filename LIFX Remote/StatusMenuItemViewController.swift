//
//  StatusMenuItemViewController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 11/13/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

class StatusMenuItemViewController: NSViewController {
    
    override var nibName: String? {
        return "StatusMenuItemViewController"
    }
    
    @IBOutlet weak var labelTextField:   NSTextField!
    @IBOutlet weak var brightnessSlider: NSSlider!
    @IBOutlet weak var lightColorView:   StatusMenuItemColorView!
    var device: LIFXDevice!

    override func viewDidLoad() {
        labelTextField.reactive.stringValue <~ device.label.map { (label) -> String in
            return label ?? "Unknown"
        }
        brightnessSlider.reactive.isEnabled <~ device.power.map { (power) -> Bool in
            return power == .enabled
        }
        if let light = device as? LIFXLight {
            brightnessSlider.reactive.integerValue <~ light.color.map { (color) -> Int in
                guard let color = color else { return 0 }
                return color.brightnessAsPercentage
            }
            lightColorView.reactive.colorValue <~ light.color.map { (color) -> NSColor? in
                guard let color = color else { return nil }
                return NSColor(from: color)
            }
        }
    }

    @IBAction func showHud(_ sender: NSClickGestureRecognizer) {
        HudController.show(device)
    }

    @IBAction func togglePower(_ sender: NSClickGestureRecognizer) {
        device.setPower(level: (device.power.value == .enabled) ? .standby : .enabled)
    }
    
    @IBAction func setBrightness(_ sender: NSSlider) {
        if let light = device as? LIFXLight {
            guard var color = light.color.value else { return }
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
