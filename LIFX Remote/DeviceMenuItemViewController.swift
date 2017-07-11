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

    @IBOutlet weak var labelTextField:   NSTextField!
    @IBOutlet weak var brightnessSlider: NSSlider!
    @IBOutlet weak var deviceColorView:  StatusMenuItemColorView!

    @objc dynamic weak var device: LIFXDevice?

    @IBAction func showHud(_ sender: NSClickGestureRecognizer) {
        guard let device = device else { return }
        HudController.show(device)
    }

    @IBAction func togglePower(_ sender: NSClickGestureRecognizer) {
        guard let device = device else { return }
        device.setPower(device.power == .enabled ? .standby : .enabled)
    }

    @IBAction func setBrightness(_ sender: NSSlider) {
        guard let light = device as? LIFXLight, let color = light.color else { return }
        color.brightness = UInt16(sender.doubleValue/sender.maxValue * Double(UInt16.max))
        light.setColor(color)
    }
}
