//
//  GroupsViewController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 1/7/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

class GroupsViewController: NSViewController {

    @IBOutlet var outlineView: NSOutlineView!
    @IBOutlet var removeGroupButton: NSButton!
    @IBOutlet var detailView: NSView! // Holds tabView, noGroupsView, noGroupsSelectedView
    @IBOutlet var tabView: NSTabView!
    @IBOutlet var noGroupsView: NSView!
    fileprivate let model = LIFXModel.shared
    fileprivate let outlineCellViewImage = NSImage(named: "NSActionTemplate")

    override func viewDidLoad() {
        preferredContentSize = NSSize(width: 450, height: 300)
        detailView.addSubview(noGroupsView)
        removeGroupButton.reactive.isEnabled <~ model.groups.map { return $0.count > 0 }
        tabView.reactive.isHidden <~ model.groups.map { return $0.count == 0 }
        noGroupsView.reactive.isHidden <~ model.groups.map { return $0.count != 0 }
        for group in model.groups.value {
            guard let viewController = storyboard?.instantiateController(withIdentifier: "GroupDetail")
                as? GroupDetailViewController else { return }
            viewController.group = group
            tabView.addTabViewItem(NSTabViewItem(viewController: viewController))
        }
    }

    @IBAction func addGroup(_ sender: NSButton) {
        let group = LIFXGroup()
        model.add(group: group)
        outlineView.reloadData()
        guard let viewController = storyboard?.instantiateController(withIdentifier: "GroupDetail")
            as? GroupDetailViewController else { return }
        viewController.group = group
        tabView.addTabViewItem(NSTabViewItem(viewController: viewController))
    }

    @IBAction func removeGroup(_ sender: NSButton) {
        let index = (outlineView.selectedRow != -1) ? outlineView.selectedRow : model.groups.value.count-1
        model.removeGroup(at: index)
        outlineView.reloadData()
        tabView.removeTabViewItem(tabView.tabViewItem(at: index))
    }
}

extension GroupsViewController: NSControlTextEditingDelegate {

    func control(_ control: NSControl, isValidObject obj: Any?) -> Bool {
        if control.identifier == "GroupName" {
            guard let newName = obj as? String else { return false }
            if model.groups.value
                .filter({ return newName == $0.name.value })
                .reduce(0, { return $0.0 + 1 }) > 0
            { return false }
        }
        return true
    }

    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        if control.identifier == "GroupName" {
            model.group(at: outlineView.row(for: control)).name.value = fieldEditor.string ?? ""
            return true
        }
        return false
    }
}

extension GroupsViewController: NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item != nil {
            return 0
        }
        return model.groups.value.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        return model.group(at: index)
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return false
    }
}

extension GroupsViewController: NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let group = item as? LIFXGroup {
            guard
                let view = outlineView.make(withIdentifier: "GroupCell", owner: nil) as? NSTableCellView,
                let textField = view.textField,
                let imageView = view.imageView
            else { return nil }
            textField.reactive.stringValue <~ group.name
            imageView.image = outlineCellViewImage
            return view
        }
        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        return true
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        tabView.selectTabViewItem(at: outlineView.selectedRow)
    }
}

extension Reactive where Base: NSView {
    var isHidden: BindingTarget<Bool> {
        return BindingTarget(on: UIScheduler(), lifetime: lifetime, setter: { [weak base = self.base] value in
            if let base = base {
                base.isHidden = value
            }
        })
    }
}
