//
//  HudGroupViewController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 1/15/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa
import Result
import ReactiveSwift
import ReactiveCocoa

class HudGroupViewController: NSViewController {

    override var nibName: NSNib.Name? {
        return NSNib.Name(rawValue: "HudGroupViewController")
    }

    @IBOutlet var colorWheel:       ColorWheel!
    @IBOutlet var kelvinSlider:     NSSlider!
    @IBOutlet var brightnessSlider: NSSlider!
    @IBOutlet var tableView:        NSTableView!
    var group: LIFXGroup!

    override func viewDidLoad() {
        group.name.producer.startWithSignal { $0.0.observeResult({ self.view.window?.title = $0 ?? "" }) }
        kelvinSlider.reactive.isEnabled <~ group.power.map { return $0 == .enabled }
        kelvinSlider.reactive.integerValue <~ group.color.map { return $0?.kelvinAsPercentage ?? 50 }
        brightnessSlider.reactive.isEnabled <~ group.power.map { return $0 == .enabled }
        brightnessSlider.reactive.integerValue <~ group.color.map { return $0?.brightnessAsPercentage ?? 0 }
        group.devices.producer.startWithSignal { $0.0.observeResult({ _ in self.tableView.reloadData() }) }
        colorWheel.target = self
        colorWheel.action = #selector(setColor(_:))
    }

    @objc func setColor(_ sender: ColorWheel) {
        guard let color = LIFXLight.Color(nsColor: sender.selectedColor) else { return }
        group.setColor(color)
    }

    @IBAction func togglePower(_ sender: NSButton) {
        group.setPower((group.power.value == .enabled) ? .standby : .enabled)
    }

    @IBAction func setKelvin(_ sender: NSSlider) {
        guard var color = group.color.value else { return }
        color.kelvin = UInt16(sender.doubleValue*65 + 2500)
        group.setColor(color)
    }

    @IBAction func setBrightness(_ sender: NSSlider) {
        guard var color = group.color.value else { return }
        color.brightness = UInt16(sender.doubleValue/sender.maxValue * Double(UInt16.max))
        group.setColor(color)
    }
}

extension HudGroupViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return group.devices.value.count
    }
}

extension HudGroupViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard tableColumn != nil else { return nil }

        let device = group.devices.value[row]
        guard
            let view = tableView.make(withIdentifier: "deviceCell", owner: nil) as? NSTableCellView,
            let textField = view.textField
        else { return nil }
        textField.reactive.stringValue <~ device.label.map { return $0 ?? "Unknown" }

        return view
    }
}
