//
//  GroupDetailViewController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 1/11/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa

private let identifierDeviceCell = NSUserInterfaceItemIdentifier(rawValue: "deviceCell")

class GroupDetailViewController: NSViewController {
    @IBOutlet weak var tableView: NSTableView!
    
    @objc dynamic weak var group: LIFXDeviceGroup!

    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(devicesChanged),
                                               name: .devicesChanged, object: nil)
    }

    @objc func devicesChanged() {
        DispatchQueue.main.async { self.tableView.reloadData() }
    }

    @IBAction func toggleIsInGroup(_ sender: NSButton) {
        let device = Model.shared.devices[tableView.row(for: sender)]
        if sender.state == .off {
            group.remove(device: device)
        } else {
            group.add(device: device)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension GroupDetailViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return Model.shared.devices.count
    }
}

extension GroupDetailViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard tableColumn != nil else { return nil }
        let device = Model.shared.devices[row]
        guard let view = tableView.makeView(withIdentifier: identifierDeviceCell, owner: nil) as? CheckboxTableCellView,
            let textField = view.textField
            else { return nil }
        view.checkbox.state = (group.devices.contains(device)) ? .on : .off
        textField.bind(.value, to: device, withKeyPath: #keyPath(LIFXDevice.label), options: nil)
        return view
    }

    func tableView(_ tableView: NSTableView, didRemove rowView: NSTableRowView, forRow row: Int) {
        guard row == -1,
            let view = rowView.view(atColumn: 0) as? CheckboxTableCellView,
            let textField = view.textField
            else { return }
        textField.unbind(.value)
    }
}
