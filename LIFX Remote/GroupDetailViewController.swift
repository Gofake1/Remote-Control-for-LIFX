//
//  GroupDetailViewController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 1/11/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

class GroupDetailViewController: NSViewController {

    @IBOutlet weak var groupNameLabel: NSTextField!
    @IBOutlet weak var tableView: NSTableView!
    
    var group: LIFXGroup!
    private let model = LIFXModel.shared

    override func viewDidLoad() {
        groupNameLabel.reactive.stringValue <~ group.name.map { return "\($0) Settings" }
        //group.devices.producer.startWithSignal { $0.0.observeResult({ _ in self.tableView.reloadData() }) }
        model.devices.producer.startWithSignal { $0.0.observeResult({ _ in self.tableView.reloadData() }) }
    }

    @IBAction func toggleIsInGroup(_ sender: NSButton) {
        let device = model.device(at: tableView.row(for: sender))
        if sender.state == 0 {
            group.remove(device: device)
        } else {
            group.add(device: device)
        }
    }
}

extension GroupDetailViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return model.devices.value.count
    }
}

extension GroupDetailViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard tableColumn != nil else { return nil }
        let device = model.device(at: row)
        guard
            let view = tableView.make(withIdentifier: "deviceCell", owner: nil) as? CheckboxTableCellView,
            let textField = view.textField
        else { return nil }
        view.checkbox.state = (group.devices.value.contains(device)) ? 1 : 0
        textField.reactive.stringValue <~ device.label.map { return $0 ?? "Unknown" }

        return view
    }
}
