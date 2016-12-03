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
    
    @IBOutlet weak var labelTextField:   NSTextField!
    @IBOutlet weak var powerButton:      NSButton!
    @IBOutlet weak var colorWheel:       ColorWheel!
    @IBOutlet weak var brightnessSlider: NSSlider!
    @IBOutlet weak var wifiTextField:    NSTextField!
    @IBOutlet weak var modelTextField:   NSTextField!
    var device:      LIFXDevice!
    var devicePower: NSNumber = 0 { // Binding
        didSet {
            device.setPower(level: (devicePower == 1) ? .enabled : .standby)
            brightnessSlider.isEnabled = (devicePower == 1) ? true : false
        }
    }

    override func viewDidLoad() {
        colorWheel.target = self
        colorWheel.action = #selector(updateColor(_:))
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
            colorWheel.selectedColor = color.cgColor
            brightnessSlider.integerValue = color.brightnessAsPercentage
        }
        if let signal = device.wifi.signal {
            wifiTextField.stringValue = String(signal) + "mw"
        }
        if let model = device.device.product {
            modelTextField.stringValue = String(describing: model)
        }
    }
    
    func updateColor(_ sender: ColorWheel) {
        if let light = device as? LIFXLight {
            guard let color = LIFXLight.Color(cgColor: sender.selectedColor) else { return }
            light.setColor(color)
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

extension LIFXLight.Color {
    init?(cgColor: CGColor) {
        guard let rgb = cgColor.components else { return nil }
        let r = rgb[0]
        let g = rgb[1]
        let b = rgb[2]
        let minRgb = min(r, min(g, b))
        let maxRgb = max(r, max(g, b))
        var hue, saturation, brightness: UInt16
        if minRgb == maxRgb {
            hue        = 0
            saturation = 0
            brightness = UInt16(maxRgb * CGFloat(UInt16.max))
        } else {
            let d: CGFloat = (r == minRgb) ? g - b : ((b == minRgb) ? r - g : b - r)
            let h: CGFloat = (r == minRgb) ? 3 : ((b == minRgb) ? 1 : 5)
            hue        = UInt16((h - d/(maxRgb - minRgb)) / 6 * CGFloat(UInt16.max))
            saturation = UInt16((maxRgb - minRgb) / maxRgb * CGFloat(UInt16.max))
            brightness = UInt16(maxRgb * CGFloat(UInt16.max))
        }
        self.init(hue: hue, saturation: saturation, brightness: brightness, kelvin: 0)
    }
}
