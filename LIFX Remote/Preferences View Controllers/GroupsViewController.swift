//
//  GroupsViewController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 1/7/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa

private let identifierGroupName = NSUserInterfaceItemIdentifier(rawValue: "groupName")
private let identifierGroupDetailViewController = NSStoryboard.SceneIdentifier(rawValue: "groupDetail")

class GroupsViewController: NSViewController {
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var detailView: NSView! // Holds tabView, noGroupsView
    @IBOutlet weak var tabView: NSTabView!
    @IBOutlet weak var noGroupsView: NSView!
    
    @objc private let model = Model.shared
    
    override func viewDidLoad() {
        preferredContentSize = NSSize(width: 450, height: 300)
        detailView.addSubview(noGroupsView)
        Model.shared.groups.forEach { addViewController(for: $0) }
    }

    @IBAction func addGroup(_ sender: NSButton) {
        let group = LIFXDeviceGroup()
        Model.shared.add(group: group)
        addViewController(for: group)
    }

    @IBAction func removeGroup(_ sender: NSButton) {
        let index = (tableView.selectedRow != -1) ? tableView.selectedRow : Model.shared.groups.count-1
        tabView.removeTabViewItem(tabView.tabViewItem(at: index))
        Model.shared.removeGroup(at: index)
    }
    
    private func addViewController(for group: LIFXDeviceGroup) {
        guard let viewController = storyboard?.instantiateController(withIdentifier:
            identifierGroupDetailViewController) as? GroupDetailViewController else { return }
        viewController.group = group
        tabView.addTabViewItem(NSTabViewItem(viewController: viewController))
    }
}

extension GroupsViewController: NSControlTextEditingDelegate {
    func control(_ control: NSControl, isValidObject obj: Any?) -> Bool {
        guard control.identifier == identifierGroupName else { return true }
        guard let newName = obj as? String else { return false }
        return Model.shared.groups.first(where: { $0.name == newName }) == nil
    }
}

extension GroupsViewController: NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {
        tabView.selectTabViewItem(at: tableView.selectedRow)
    }
}
