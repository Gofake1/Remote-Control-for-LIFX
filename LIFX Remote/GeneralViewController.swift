//
//  GeneralViewController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 1/7/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

class GeneralViewController: NSViewController {

    @IBOutlet var tableView: NSTableView!
    fileprivate let model = LIFXModel.shared

    override func viewDidLoad() {
        preferredContentSize = NSSize(width: 450, height: 300)
        model.onDiscovery { self.tableView.reloadData() }
        model.groups.producer.startWithSignal { $0.0.observeResult({ _ in self.tableView.reloadData() }) }
    }

    @IBAction func searchForDevices(_ sender: NSButton) {
        model.discover()
    }

    @IBAction func toggleShouldDisplay(_ sender: NSButton) {
//        switch model.item(at: tableView.row(for: sender)) {
//        case .left(let group):
//            model.setVisibility(for: group, sender.state == 1)
//        case .right(let device):
//            model.setVisibility(for: device, sender.state == 1)
//        }
    }
}

extension GeneralViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return model.groups.value.count + model.devices.value.count
    }
}

extension GeneralViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn else { return nil }

        switch tableColumn.identifier {
//        case "shouldDisplay":
//            let view = tableView.make(withIdentifier: "shouldDisplayCell", owner: nil) as? CheckboxTableCellView
//            switch model.item(at: row) {
//            case .left(let group):
//                if let visibility = model.itemVisibility[group] {
//                    view?.checkbox.state = visibility ? 1 : 0
//                }
//            case .right(let device):
//                print(device)
//                view?.checkbox.state = model.itemVisibility[device]! ? 1 : 0
//            }
//            return view

        case "deviceOrGroup":
            switch model.item(at: row) {
            case .left(let group):
                guard
                    let view = tableView.make(withIdentifier: "groupCell", owner: nil) as? NSTableCellView,
                    let textField = view.textField
                else { return nil }
                textField.reactive.stringValue <~ group.name
                return view
            case .right(let device):
                guard
                    let view = tableView.make(withIdentifier: "deviceCell", owner: nil) as? NSTableCellView,
                    let textField = view.textField
                else { return nil }
                textField.reactive.stringValue <~ device.label.map { return $0 ?? "Unknown" }
                return view
            }

//        case "ipAddress":
//            switch model.item(at: row) {
//            case .left:
//                return nil
//            case .right(let device):
//                guard
//                    let view = tableView.make(withIdentifier: "ipAddressCell", owner: nil) as? NSTableCellView,
//                    let textField = view.textField
//                else { return nil }
//                textField.reactive.stringValue <~ device.ipAddress.map { return $0 ?? "Unknown" }
//                return view
//            }

        default: return nil
        }
    }
}
