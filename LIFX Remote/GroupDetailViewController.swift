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
    
    @objc weak var group: LIFXGroup!
    private unowned let model = LIFXModel.shared

    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(GroupDetailViewController.refreshTable),
                                               name: notificationDevicesChanged,
                                               object: model)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(GroupDetailViewController.updateGroupName),
                                               name: notificationGroupNameChanged,
                                               object: group)
    }

    @objc func refreshTable() {
        tableView.reloadData()
    }

    @objc func updateGroupName() {
        groupNameLabel.stringValue = "\(group.name) Settings"
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
        textField.bind(NSBindingName(rawValue: "value"),
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
        textField.unbind(NSBindingName(rawValue: "value"))
    }
}
