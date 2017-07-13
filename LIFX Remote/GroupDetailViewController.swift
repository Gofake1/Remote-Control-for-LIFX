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

    @IBOutlet weak var groupNameLabel: NSTextField!
    @IBOutlet weak var tableView: NSTableView!
    
    weak var group: LIFXGroup!
    private let model = LIFXModel.shared

    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(GroupDetailViewController.devicesChanged),
                                               name: notificationDevicesChanged,
                                               object: model)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(GroupDetailViewController.groupNameChanged),
                                               name: notificationGroupNameChanged,
                                               object: group)
        groupNameLabel.stringValue = "\(group.name) Settings"
    }

    @objc func devicesChanged() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    @objc func groupNameChanged() {
        DispatchQueue.main.async {
            self.groupNameLabel.stringValue = "\(self.group.name) Settings"
        }
    }

    @IBAction func toggleIsInGroup(_ sender: NSButton) {
        let device = model.device(at: tableView.row(for: sender))
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
        return model.devices.count
    }
}

extension GroupDetailViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard tableColumn != nil else { return nil }
        let device = model.device(at: row)
        guard let view = tableView.makeView(withIdentifier: identifierDeviceCell, owner: nil) as? CheckboxTableCellView,
            let textField = view.textField
            else { return nil }
        view.checkbox.state = (group.devices.contains(device)) ? .on : .off
        textField.bind(NSBindingName.value,
                       to: device,
                       withKeyPath: #keyPath(LIFXDevice.label),
                       options: nil)
        return view
    }

    func tableView(_ tableView: NSTableView, didRemove rowView: NSTableRowView, forRow row: Int) {
        print(row) //*
        guard row == -1,
            let view = rowView.view(atColumn: 0) as? CheckboxTableCellView,
            let textField = view.textField
            else { return }
        textField.unbind(NSBindingName.value)
    }
}
