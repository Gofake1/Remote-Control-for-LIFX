//
//  DeviceMenuItemViewController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 7/10/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa

class DeviceMenuItemViewController: NSViewController {

    override var nibName: NSNib.Name? {
        return NSNib.Name(rawValue: "DeviceMenuItemViewController")
    }

    @IBOutlet weak var deviceColorView:  StatusMenuItemColorView!
    @IBOutlet weak var brightnessSlider: NSSlider!

    @objc weak var device: LIFXDevice!

    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(DeviceMenuItemViewController.devicePowerChanged),
                                               name: notificationDevicePowerChanged,
                                               object: device)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(DeviceMenuItemViewController.lightColorChanged),
                                               name: notificationLightColorChanged,
                                               object: device)
    }

    @objc func devicePowerChanged() {
        brightnessSlider.isEnabled = device.power == .enabled
    }

    @objc func lightColorChanged() {
        if let light = device as? LIFXLight {
            deviceColorView.color = light.color?.nsColor
            brightnessSlider.integerValue = light.color?.brightnessAsPercentage ?? 0
        }
    }

    @IBAction func showHud(_ sender: NSClickGestureRecognizer) {
        device.hudController.showWindow(nil)
    }

    @IBAction func togglePower(_ sender: NSButton) {
        device.setPower(device.power == .enabled ? .standby : .enabled)
    }

    @IBAction func setBrightness(_ sender: NSSlider) {
        guard let light = device as? LIFXLight, var color = light.color else { return }
        color.brightness = UInt16(percentage: sender.doubleValue)
        light.setColor(color)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
