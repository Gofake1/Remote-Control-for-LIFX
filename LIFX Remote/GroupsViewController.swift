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
    @IBOutlet weak var removeGroupButton: NSButton!
    @IBOutlet weak var detailView: NSView! // Holds tabView, noGroupsView, noGroupsSelectedView
    @IBOutlet weak var tabView: NSTabView!
    @IBOutlet weak var noGroupsView: NSView!
    
    @objc private unowned let model = LIFXModel.shared

    override func viewDidLoad() {
        preferredContentSize = NSSize(width: 450, height: 300)
        detailView.addSubview(noGroupsView)
        model.onGroupsCountChange { count in
            self.removeGroupButton.isEnabled = count > 0
            self.tabView.isHidden = count == 0
            self.noGroupsView.isHidden = count > 0
        }
        model.groups.forEach { addViewController(for: $0) }
        self.removeGroupButton.isEnabled = model.groups.count > 0
        self.tabView.isHidden = model.groups.count == 0
        self.noGroupsView.isHidden = model.groups.count > 0
    }

    func addViewController(for group: LIFXGroup) {
        guard let viewController = storyboard?.instantiateController(withIdentifier:
            identifierGroupDetailViewController) as? GroupDetailViewController else { return }
        viewController.group = group
        tabView.addTabViewItem(NSTabViewItem(viewController: viewController))
    }

    @IBAction func addGroup(_ sender: NSButton) {
        let group = LIFXGroup()
        model.add(group: group)
        addViewController(for: group)
    }

    @IBAction func removeGroup(_ sender: NSButton) {
        let index = (tableView.selectedRow != -1) ? tableView.selectedRow : model.groups.count-1
        let group = model.group(at: index)
        HudController.removeGroup(group)
        model.remove(group: group)
        tabView.removeTabViewItem(tabView.tabViewItem(at: index))
    }
}

extension GroupsViewController: NSControlTextEditingDelegate {
    func control(_ control: NSControl, isValidObject obj: Any?) -> Bool {
        if control.identifier == identifierGroupName {
            guard let newName = obj as? String else { return false }
            if model.groups
                .filter({ return newName == $0.name })
                .reduce(0, { (result, _) -> Int in return result + 1 }) > 0
            { return false }
        }
        return true
    }
}

extension GroupsViewController: NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {
        tabView.selectTabViewItem(at: tableView.selectedRow)
    }
}
