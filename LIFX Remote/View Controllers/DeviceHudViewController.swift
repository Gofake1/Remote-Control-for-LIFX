//
//  HudDeviceViewController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 11/20/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa

class DeviceHudViewController: NSViewController {
    @IBOutlet weak var colorWheel:       ColorWheel!
    @IBOutlet weak var kelvinSlider:     NSSlider!
    @IBOutlet weak var brightnessSlider: NSSlider!
    @IBOutlet weak var wifiTextField:    NSTextField!
    @IBOutlet weak var modelTextField:   NSTextField!

    @objc weak var device: LIFXDevice!

    override var nibName: NSNib.Name? {
        return NSNib.Name(rawValue: "DeviceHudViewController")
    }

    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(deviceNameChanged),
                                               name: .deviceLabelChanged, object: device)
        NotificationCenter.default.addObserver(self, selector: #selector(devicePowerChanged),
                                               name: .devicePowerChanged, object: device)
        NotificationCenter.default.addObserver(self, selector: #selector(deviceWifiChanged),
                                               name: .deviceWifiChanged, object: device)
        NotificationCenter.default.addObserver(self, selector: #selector(deviceModelChanged),
                                               name: .deviceModelChanged, object: device)
        NotificationCenter.default.addObserver(self, selector: #selector(lightColorChanged),
                                               name: .lightColorChanged, object: device)
        colorWheel.target = self
        colorWheel.action = #selector(setColor(_:))
        updateControls()
        device.getVersion()
    }

    override func viewWillAppear() {
        device.getWifiInfo()
    }

    @objc func deviceNameChanged() {
        guard let window = view.window else { return }
        window.title = device.label
    }

    @objc func devicePowerChanged() {
        kelvinSlider.isEnabled = device.power == .enabled
        brightnessSlider.isEnabled = device.power == .enabled
    }

    @objc func deviceWifiChanged() {
        guard let signal = device.wifiInfo.signal else { wifiTextField.stringValue = "Unknown"; return }
        let dBm = log(signal)
        switch dBm {
        case _ where dBm > -35: wifiTextField.stringValue = "••••"
        case _ where dBm > -50: wifiTextField.stringValue = "•••◦"
        case _ where dBm > -65: wifiTextField.stringValue = "••◦◦"
        case _ where dBm > -80: wifiTextField.stringValue = "•◦◦◦"
        case _ where dBm > -95: wifiTextField.stringValue = "◦◦◦◦"
        default:                wifiTextField.stringValue = "Error"
        }
    }

    @objc func deviceModelChanged() {
        guard let model = device.deviceInfo.product else { modelTextField.stringValue = "Unknown"; return }
        modelTextField.stringValue = String(describing: model)
    }

    @objc func lightColorChanged() {
        updateControls()
    }

    @objc func setColor(_ sender: ColorWheel) {
        if let light = device as? LIFXLight {
            light.setColor(LIFXLight.Color(nsColor: sender.selectedColor))
        }
    }

    @IBAction func togglePower(_ sender: NSButton) {
        device.setPower((device.power == .enabled) ? .standby : .enabled)
    }

    @IBAction func setKelvin(_ sender: NSSlider) {
        if let light = device as? LIFXLight {
            guard var color = light.color else { return }
            color.kelvin = UInt16(sender.doubleValue*65 + 2500)
            light.setColor(color)
        }
    }
    
    @IBAction func setBrightness(_ sender: NSSlider) {
        if let light = device as? LIFXLight {
            guard var color = light.color else { return }
            color.brightness = UInt16(sender.doubleValue/sender.maxValue * Double(UInt16.max))
            light.setColor(color)
            colorWheel.setColor(color.nsColor)
        }
    }

    @IBAction func updateWifi(_ sender: NSClickGestureRecognizer) {
        device.getWifiInfo()
    }

    @IBAction func updateProduct(_ sender: NSClickGestureRecognizer) {
        device.getVersion()
    }

    private func updateControls() {
        if let light = device as? LIFXLight {
            kelvinSlider.integerValue = light.color?.kelvinAsPercentage ?? 0
            brightnessSlider.integerValue = light.color?.brightnessAsPercentage ?? 0
            colorWheel.setColor(light.color?.nsColor)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
