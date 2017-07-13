//
//  HudGroupViewController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 1/15/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa

class GroupHudViewController: NSViewController {

    override var nibName: NSNib.Name? {
        return NSNib.Name(rawValue: "GroupHudViewController")
    }

    @IBOutlet weak var colorWheel:       ColorWheel!
    @IBOutlet weak var kelvinSlider:     NSSlider!
    @IBOutlet weak var brightnessSlider: NSSlider!

    @objc weak var group: LIFXGroup!

    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(GroupHudViewController.groupNameChanged),
                                               name: notificationGroupNameChanged,
                                               object: group)
        kelvinSlider.isEnabled = group.power == .enabled
        brightnessSlider.isEnabled = group.power == .enabled
        colorWheel.target = self
        colorWheel.action = #selector(setColor(_:))
    }

    @objc func groupNameChanged() {
        guard let window = view.window else { return }
        window.title = group.name
    }

    @objc func setColor(_ sender: ColorWheel) {
        group.setColor(LIFXLight.Color(nsColor: sender.selectedColor))
    }

    @IBAction func togglePower(_ sender: NSButton) {
        group.setPower((group.power == .enabled) ? .standby : .enabled)
        kelvinSlider.isEnabled = group.power == .enabled
        brightnessSlider.isEnabled = group.power == .enabled
    }

    @IBAction func setKelvin(_ sender: NSSlider) {
        guard var color = group.color else { return }
        color.kelvin = UInt16(sender.doubleValue*65 + 2500)
        group.setColor(color)
    }

    @IBAction func setBrightness(_ sender: NSSlider) {
        guard var color = group.color else { return }
        color.brightness = UInt16(sender.doubleValue/sender.maxValue * Double(UInt16.max))
        group.setColor(color)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
