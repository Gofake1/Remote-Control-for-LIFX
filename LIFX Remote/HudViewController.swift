//
//  HudViewController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 11/20/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

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
            colorWheel.reactive.colorValue <~ light.color.map { (color) -> CGColor in
                guard let color = color else { return CGColor(red: 1, green: 1, blue: 1, alpha: 1) }
                return color.cgColor
            }
        }
        wifiTextField.reactive.stringValue <~ device.wifi.map { (wifi) -> String in
            guard let signal = wifi.signal else { return "Unknown" }
            let dBm = log(signal)
            switch dBm {
            case _ where dBm > -35: return "••••"
            case _ where dBm > -50: return "•••◦"
            case _ where dBm > -65: return "••◦◦"
            case _ where dBm > -80: return "•◦◦◦"
            case _ where dBm > -95: return "◦◦◦◦"
            default:                return "Error"
            }
        }
        modelTextField.reactive.stringValue <~ device.deviceInfo.map { (deviceInfo) -> String in
            guard let model = deviceInfo.product else { return "Unknown" }
            return String(describing: model)
        }
        colorWheel.target = self
        colorWheel.action = #selector(setColor(_:))
    }

    override func viewWillAppear() {
        device.getWifiInfo()
    }

    func setColor(_ sender: ColorWheel) {
        if let light = device as? LIFXLight {
            guard let color = LIFXLight.Color(cgColor: sender.selectedColor) else { return }
            light.setColor(color)
        }
    }

    @IBAction func togglePower(_ sender: NSButton) {
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
