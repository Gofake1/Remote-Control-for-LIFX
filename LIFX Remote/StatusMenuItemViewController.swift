//
//  StatusMenuItemViewController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 11/13/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

class StatusMenuItemViewController: NSViewController {
    
    override var nibName: String? {
        return "StatusMenuItemViewController"
    }
    
    @IBOutlet var labelTextField:   NSTextField!
    @IBOutlet var brightnessSlider: NSSlider!
    @IBOutlet var lightColorView:   StatusMenuItemColorView!
    var item: Either<LIFXGroup, LIFXDevice>?

    override func viewDidLoad() {
        guard let item = item else { return }
        switch item {
        case .left(let group):
            labelTextField.reactive.stringValue <~ group.name
            brightnessSlider.reactive.isEnabled <~ group.power.map { return $0 == .enabled }
            brightnessSlider.reactive.integerValue <~ group.color.map { return $0?.brightnessAsPercentage ?? 0 }
            lightColorView.reactive.colorValue <~ group.color.map { return NSColor(from: $0) }
        case .right(let device):
            labelTextField.reactive.stringValue <~ device.label.map { return $0 ?? "Unknown" }
            brightnessSlider.reactive.isEnabled <~ device.power.map { return $0 == .enabled }
            if let light = device as? LIFXLight {
                brightnessSlider.reactive.integerValue <~
                    light.color.map { return $0?.brightnessAsPercentage ?? 0 }
                lightColorView.reactive.colorValue <~ light.color.map { return NSColor(from: $0) }
            }
        }
    }

    @IBAction func showHud(_ sender: NSClickGestureRecognizer) {
        guard let item = item else { return }
        switch item {
        case .left(let group):
            HudController.show(Either.left(group))
        case .right(let device):
            HudController.show(Either.right(device))
        }
    }

    @IBAction func togglePower(_ sender: NSClickGestureRecognizer) {
        guard let item = item else { return }
        switch item {
        case .left(let group):
            group.setPower((group.power.value == .enabled) ? .standby : .enabled)
        case .right(let device):
            device.setPower((device.power.value == .enabled) ? .standby : .enabled)
        }
    }
    
    @IBAction func setBrightness(_ sender: NSSlider) {
        guard let item = item else { return }
        switch item {
        case .left(let group):
            guard var color = group.color.value else { return }
            color.brightness = UInt16(sender.doubleValue/sender.maxValue * Double(UInt16.max))
            group.setColor(color)
        case .right(let device):
            if let light = device as? LIFXLight {
                guard var color = light.color.value else { return }
                color.brightness = UInt16(sender.doubleValue/sender.maxValue * Double(UInt16.max))
                light.setColor(color)
            }
        }
    }
}

extension NSColor {
    convenience init?(from color: LIFXLight.Color?) {
        if let color = color {
            self.init(hue:        CGFloat(color.hue)        / CGFloat(UInt16.max),
                      saturation: CGFloat(color.saturation) / CGFloat(UInt16.max),
                      brightness: CGFloat(color.brightness) / CGFloat(UInt16.max),
                      alpha:      1.0)
        } else {
            return nil
        }
    }
}
