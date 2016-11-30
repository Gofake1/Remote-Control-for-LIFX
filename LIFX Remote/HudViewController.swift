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
    @IBOutlet weak var brightnessSlider: NSSlider!
    @IBOutlet weak var wifiTextField: NSTextField!
    @IBOutlet weak var modelTextLabel: NSTextField!
    var device: LIFXDevice!
    var devicePower: NSNumber = 0 {
        didSet {
            device.setPower(level: (devicePower == 1) ? .enabled : .standby)
            brightnessSlider.isEnabled = (devicePower == 1) ? true : false
        }
    }

    override func viewDidLoad() {
        updateViews()
    }
    
    override func viewWillAppear() {
        updateViews()
    }
    
    func updateViews() {
        labelTextField.stringValue = device.label ?? "Unknown"
        devicePower = (device.power == .enabled) ? 1 : 0
        if let light = device as? LIFXLight {
            guard let color = light.color else { return }
            brightnessSlider.integerValue = color.brightnessAsPercentage
        }
    }
    
    @IBAction func updateBrightness(_ sender: NSSlider) {
        if let light = device as? LIFXLight {
            guard var color = light.color else { return }
            color.brightness = UInt16(sender.doubleValue/sender.maxValue * Double(UInt16.max))
            light.setColor(color)
        }
    }
}
