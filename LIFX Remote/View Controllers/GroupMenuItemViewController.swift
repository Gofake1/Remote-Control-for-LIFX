//
//  GroupMenuItemViewController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 7/10/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa

class GroupMenuItemViewController: NSViewController {
    @IBOutlet weak var brightnessSlider: NSSlider!

    @objc weak var group: LIFXDeviceGroup!

    override var nibName: NSNib.Name? {
        return NSNib.Name(rawValue: "GroupMenuItemViewController")
    }

    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(groupColorChanged),
                                               name: .groupColorChanged, object: group)
        NotificationCenter.default.addObserver(self, selector: #selector(groupPowerChanged),
                                               name: .groupPowerChanged, object: group)
    }

    @objc func groupColorChanged() {
        brightnessSlider.integerValue = group.color.brightnessAsPercentage
    }

    @objc func groupPowerChanged() {
        brightnessSlider.isEnabled = group.power == .enabled
    }

    @IBAction func showHud(_ sender: NSClickGestureRecognizer) {
        group.hudController.showWindow(nil)
    }

    @IBAction func togglePower(_ sender: NSButton) {
        group.setPower(group.power == .enabled ? .standby : .enabled)
    }

    @IBAction func setBrightness(_ sender: NSSlider) {
        var color = group.color
        color.brightness = UInt16(percentage: sender.doubleValue)
        group.setColor(color)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
