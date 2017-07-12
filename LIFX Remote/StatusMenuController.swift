//
//  StatusMenuController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 7/13/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa

private let statusMessages: [LIFXNetworkController.Status: String] = [
    .normal:  "LIFX: Normal",
    .offline: "LIFX: Offline"
]

class StatusMenuController: NSObject {

    enum ToggleAllMessage: String {
        case on  = "Turn On All Lights"
        case off = "Turn Off All Lights"

        mutating func flip() {
            self = (self == .on) ? .off : .on
        }
    }
    
    @IBOutlet weak var statusMenu:            NSMenu!
    @IBOutlet weak var statusMessageMenuItem: NSMenuItem!
    @IBOutlet weak var toggleAllMenuItem:     NSMenuItem!
    @IBOutlet weak var placeholderMenuItem:   NSMenuItem!

    private unowned let model    = LIFXModel.shared
    private let statusItem       = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var menuItems        = [AnyHashable: NSMenuItem]()
    private var toggleAllMessage = ToggleAllMessage.on {
        didSet {
            toggleAllMenuItem.title = toggleAllMessage.rawValue
        }
    }
    
    override func awakeFromNib() {
        statusItem.image = #imageLiteral(resourceName: "StatusBarButtonImage")
        statusItem.menu = statusMenu

        //model.restoreGroups()
        model.onStatusChange { status in
            self.statusMessageMenuItem.title = statusMessages[status]!
        }
        model.onDevicesCountChange { count in
            self.updateMenu()
            self.toggleAllMenuItem.isEnabled = count > 0
            self.placeholderMenuItem.isHidden = count == 0
        }
        model.discover()
    }
    
    func updateMenu() {
        // Remove menu items that don't have a corresponding group or device after model update
        for (object, menuItem) in menuItems {
            switch object {
            case let object as LIFXGroup:
                if model.groups.contains(object) { continue }
            case let object as LIFXDevice:
                if model.devices.contains(object) { continue }
            default: continue
            }
            statusMenu.removeItem(menuItem)
            menuItems[object] = nil
        }

        for array in [model.groups, model.devices] as [[AnyHashable]] {
            for item in array {
                // Check if existing menu items should be hidden
                if menuItems[item] != nil {
                    if model.itemVisibility[item] != true {
                        // Remove item because isHidden property doesn't work as expected
                        statusMenu.removeItem(menuItems[item]!)
                        menuItems[item] = nil
                    }
                    continue
                }

                // Don't create menu item if it should be hidden
                guard model.itemVisibility[item]! else { continue }

                // Add new menu items for new groups and devices after model update
                let menuItem = NSMenuItem()
                let menuItemViewController: NSViewController
                var index: Int
                switch item {
                case let group as LIFXGroup:
                    menuItemViewController = GroupMenuItemViewController()
                    (menuItemViewController as! GroupMenuItemViewController).group = group
                    index = statusMenu.index(of: placeholderMenuItem)
                case let device as LIFXDevice:
                    menuItemViewController = DeviceMenuItemViewController()
                    (menuItemViewController as! DeviceMenuItemViewController).device = device
                    index = statusMenu.index(of: placeholderMenuItem) + 1
                default: continue
                }
                menuItem.representedObject = menuItemViewController
                menuItem.view = menuItemViewController.view
                statusMenu.insertItem(menuItem, at: index)
                menuItems[item] = menuItem
            }
        }
    }
    
    @IBAction func toggleAllLights(_ sender: NSMenuItem) {
        model.changeAllDevices(power: (toggleAllMessage == .on) ? .enabled : .standby)
        toggleAllMessage.flip()
    }
}

extension StatusMenuController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        updateMenu()
        for device in model.devices {
            if let light = device as? LIFXLight {
                light.getState()
            }
        }
    }
}
