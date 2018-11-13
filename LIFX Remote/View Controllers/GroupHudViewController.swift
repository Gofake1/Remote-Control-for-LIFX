//
//  HudGroupViewController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 1/15/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa

class GroupHudViewController: NSViewController {
    @IBOutlet weak var colorWheel:       ColorWheel!
    @IBOutlet weak var kelvinSlider:     NSSlider!
    @IBOutlet weak var brightnessSlider: NSSlider!

    @objc weak var group: LIFXDeviceGroup!

    override var nibName: NSNib.Name? {
        return NSNib.Name(rawValue: "GroupHudViewController")
    }

    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(groupColorChanged),
                                               name: .groupColorChanged, object: group)
        NotificationCenter.default.addObserver(self, selector: #selector(groupNameChanged),
                                               name: .groupNameChanged, object: group)
        NotificationCenter.default.addObserver(self, selector: #selector(groupPowerChanged),
                                               name: .groupPowerChanged, object: group)
        colorWheel.target = self
        colorWheel.action = #selector(setColor(_:))
        kelvinSlider.integerValue = group.color.kelvinAsPercentage
        kelvinSlider.isEnabled = group.power == .enabled
        brightnessSlider.integerValue = group.color.brightnessAsPercentage
        brightnessSlider.isEnabled = group.power == .enabled
    }

    @objc func groupColorChanged() {
        colorWheel.setColor(group.color.nsColor)
        kelvinSlider.integerValue = group.color.kelvinAsPercentage
        brightnessSlider.integerValue = group.color.brightnessAsPercentage
    }

    @objc func groupNameChanged() {
        guard let window = view.window else { return }
        window.title = group.name
    }

    @objc func groupPowerChanged() {
        kelvinSlider.isEnabled = group.power == .enabled
        brightnessSlider.isEnabled = group.power == .enabled
    }

    @objc func setColor(_ sender: ColorWheel) {
        group.setColor(LIFXLight.Color(nsColor: sender.selectedColor))
    }

    @IBAction func togglePower(_ sender: NSButton) {
        group.setPower((group.power == .enabled) ? .standby : .enabled)
    }

    @IBAction func setKelvin(_ sender: NSSlider) {
        var color = group.color
        color.kelvin = UInt16(sender.doubleValue*65 + 2500)
        group.setColor(color)
    }

    @IBAction func setBrightness(_ sender: NSSlider) {
        var color = group.color
        color.brightness = UInt16(sender.doubleValue/sender.maxValue * Double(UInt16.max))
        group.setColor(color)
        colorWheel.setColor(color.nsColor)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
