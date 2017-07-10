//
//  HudDeviceViewController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 11/20/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

class DeviceHudViewController: NSViewController {
    
    override var nibName: NSNib.Name? {
        return NSNib.Name(rawValue: "DeviceHudViewController")
    }
    
    @IBOutlet weak var colorWheel:       ColorWheel!
    @IBOutlet weak var kelvinSlider:     NSSlider!
    @IBOutlet weak var brightnessSlider: NSSlider!
    @IBOutlet weak var wifiTextField:    NSTextField!
    @IBOutlet weak var modelTextField:   NSTextField!

    unowned var device: LIFXDevice!

    override func viewDidLoad() {
        device.label.producer.startWithSignal {
            $0.0.observeResult({ self.view.window?.title = ($0.value ?? "Unknown") ?? "" })
        }
        kelvinSlider.reactive.isEnabled <~ device.power.map { return $0 == .enabled }
        brightnessSlider.reactive.isEnabled <~ device.power.map { return $0 == .enabled }
        if let light = device as? LIFXLight {
            kelvinSlider.reactive.integerValue <~ light.color.map { return $0?.kelvinAsPercentage ?? 50 }
            brightnessSlider.reactive.integerValue <~ light.color.map { return $0?.brightnessAsPercentage ?? 0 }
            colorWheel.reactive.selectedColorValue <~
                light.color.map { return $0?.nsColor ?? NSColor.black }
        }
        wifiTextField.reactive.stringValue <~ device.wifi.map {
            guard let signal = $0.signal else { return "Unknown" }
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
        modelTextField.reactive.stringValue <~ device.deviceInfo.map {
            guard let model = $0.product else { return "Unknown" }
            return String(describing: model)
        }
        colorWheel.target = self
        colorWheel.action = #selector(setColor(_:))
    }

    override func viewWillAppear() {
        device.getWifiInfo()
    }

    @objc func setColor(_ sender: ColorWheel) {
        if let light = device as? LIFXLight {
            guard let color = LIFXLight.Color(nsColor: sender.selectedColor) else { return }
            light.setColor(color)
        }
    }

    @IBAction func togglePower(_ sender: NSButton) {
        device.setPower((device.power.value == .enabled) ? .standby : .enabled)
    }

    @IBAction func setKelvin(_ sender: NSSlider) {
        if let light = device as? LIFXLight {
            guard var color = light.color.value else { return }
            color.kelvin = UInt16(sender.doubleValue*65 + 2500)
            light.setColor(color)
        }
    }
    
    @IBAction func setBrightness(_ sender: NSSlider) {
        if let light = device as? LIFXLight {
            guard var color = light.color.value else { return }
            color.brightness = UInt16(sender.doubleValue/sender.maxValue * Double(UInt16.max))
            light.setColor(color)
        }
    }

    @IBAction func updateWifi(_ sender: NSClickGestureRecognizer) {
        device.getWifiInfo()
    }

    @IBAction func updateProduct(_ sender: NSClickGestureRecognizer) {
        device.getVersion()
    }
}