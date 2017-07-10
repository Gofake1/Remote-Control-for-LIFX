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

private let identifierShouldDisplayColumn = NSUserInterfaceItemIdentifier(rawValue: "shouldDisplay")
private let identifierShouldDisplayCell   = NSUserInterfaceItemIdentifier(rawValue: "shouldDisplayCell")
private let identifierDeviceOrGroupColumn = NSUserInterfaceItemIdentifier(rawValue: "deviceOrGroup")
private let identifierGroupCell           = NSUserInterfaceItemIdentifier(rawValue: "groupCell")
private let identifierDeviceCell          = NSUserInterfaceItemIdentifier(rawValue: "deviceCell")
private let identifierIpAddress           = NSUserInterfaceItemIdentifier(rawValue: "ipAddress")
private let identifierIpAddressCell       = NSUserInterfaceItemIdentifier(rawValue: "ipAddressCell")

class GeneralViewController: NSViewController {

    @IBOutlet weak var tableView: NSTableView!

    private let model = LIFXModel.shared

    override func viewDidLoad() {
        preferredContentSize = NSSize(width: 450, height: 300)
        model.onDiscovery { self.tableView.reloadData() }
        model.groups.producer.startWithSignal { $0.0.observeResult({ _ in self.tableView.reloadData() }) }
    }

    @IBAction func searchForDevices(_ sender: NSButton) {
        model.discover()
    }

    @IBAction func toggleShouldDisplay(_ sender: NSButton) {
        switch model.item(at: tableView.row(for: sender)) {
        case .left(let group):
            model.setVisibility(for: group, sender.state == .on)
        case .right(let device):
            model.setVisibility(for: device, sender.state == .on)
        }
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
        case identifierShouldDisplayColumn:
            let view = tableView.makeView(withIdentifier: identifierShouldDisplayCell,
                                          owner: nil) as? CheckboxTableCellView
            switch model.item(at: row) {
            case .left(let group):
                if let visibility = model.itemVisibility[group] {
                    view?.checkbox.state = visibility ? .on : .off
                }
            case .right(let device):
                if let visibility = model.itemVisibility[device] {
                    view?.checkbox.state = visibility ? .on : .off
                }
            }
            return view

        case identifierDeviceOrGroupColumn:
            switch model.item(at: row) {
            case .left(let group):
                guard
                    let view = tableView.makeView(withIdentifier: identifierGroupCell,
                                                  owner: nil) as? NSTableCellView,
                    let textField = view.textField
                else { return nil }
                textField.reactive.stringValue <~ group.name
                return view
            case .right(let device):
                guard
                    let view = tableView.makeView(withIdentifier: identifierDeviceCell,
                                                  owner: nil) as? NSTableCellView,
                    let textField = view.textField
                else { return nil }
                textField.reactive.stringValue <~ device.label.map { return $0 ?? "Unknown" }
                return view
            }

        case identifierIpAddress:
            let view = tableView.makeView(withIdentifier: identifierIpAddressCell,
                                          owner: nil) as? NSTableCellView
            switch model.item(at: row) {
            case .left:
                view?.textField?.stringValue = "-"
            case .right(let device):
                view?.textField?.stringValue = device.ipAddress ?? "Unknown"
            }
            return view

        default: return nil
        }
    }
}
