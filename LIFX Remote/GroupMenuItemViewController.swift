//
//  GroupMenuItemViewController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 7/10/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa

class GroupMenuItemViewController: NSViewController {

    override var nibName: NSNib.Name? {
        return NSNib.Name(rawValue: "GroupMenuItemViewController")
    }

    @IBOutlet weak var groupColorsView: StatusMenuItemColorView!

    @objc dynamic weak var group: LIFXGroup!

    @IBAction func showHud(_ sender: NSClickGestureRecognizer) {
        HudController.show(group)
    }

    @IBAction func togglePower(_ sender: NSClickGestureRecognizer) {
        group.setPower(group.power == .enabled ? .standby : .enabled)
    }

    @IBAction func setBrightness(_ sender: NSSlider) {
        guard var color = group.color else { return }
        color.brightness = UInt16(sender.doubleValue/sender.maxValue * Double(UInt16.max))
        group.setColor(color)
    }
}
