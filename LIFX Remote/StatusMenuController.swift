//
//  StatusMenuController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 7/13/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa
import ReactiveSwift

class StatusMenuController: NSObject, NSMenuDelegate {
    
    enum StatusMessage: String {
        case normal    = "LIFX: Normal"
        case searching = "LIFX: Looking for Devices..."
    }

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
    private let statusItem       = NSStatusBar.system().statusItem(withLength: NSSquareStatusItemLength)
    private var deviceMenuItems  = [LIFXDevice:NSMenuItem]()
    private let model            = LIFXModel()
    private let statusMessage    = MutableProperty<StatusMessage>(.normal)
    private let toggleAllMessage = MutableProperty<ToggleAllMessage>(.on)
    private let preferences      = PreferencesWindowController()
    
    override func awakeFromNib() {
        statusItem.image = NSImage(named: "StatusBarButtonImage")
        statusMessageMenuItem.reactive.titleValue <~ statusMessage.map { (status) -> String in
            return status.rawValue
        }
        toggleAllMenuItem.reactive.titleValue <~ toggleAllMessage.map { (state) -> String in
            return state.rawValue
        }
        statusItem.menu = statusMenu
        
        model.onDiscovery {
            self.updateMenu()
        }
        model.discover()

        preferences.model = model
    }
    
    private func updateMenu() {
        // Remove menu items that don't have a corresponding device after model update
        for (oldDevice, menuItem) in deviceMenuItems {
            if !model.devices.value.contains(oldDevice) {
                statusMenu.removeItem(menuItem)
                deviceMenuItems[oldDevice] = nil
            }
        }
        
        if model.devices.value.count > 0 {
            placeholderMenuItem.isHidden = true
            for device in model.devices.value {
                // Skip existing menu item views
                if deviceMenuItems[device] != nil {
                    continue
                }
                // Add new menu items for new devices after model update
                let menuItemController = StatusMenuItemViewController()
                menuItemController.device = device
                let menuItem = NSMenuItem()
                menuItem.representedObject = menuItemController
                menuItem.view = menuItemController.view
                menuItem.target = self
                menuItem.action = #selector(doNothing(_:))
                statusMenu.insertItem(menuItem, at: statusMenu.index(of: placeholderMenuItem))
                deviceMenuItems[device] = menuItem
            }
        } else {
            toggleAllMenuItem.isEnabled  = false
            placeholderMenuItem.isHidden = false
        }
    }
    
    // Needed so that validateMenuItem() returns true and allows HighlightingView to draw
    func doNothing(_ sender: NSMenuItem) {}
    
    @IBAction func toggleAllLights(_ sender: NSMenuItem) {
        model.changeAllDevices(state: (toggleAllMessage.value == .on) ? .enabled : .standby)
        toggleAllMessage.value.flip()
    }
    
    @IBAction func showPreferences(_ sender: NSMenuItem) {
        preferences.showWindow(nil)
    }
    
    // MARK: - NSMenuDelegate
    
    func menuWillOpen(_ menu: NSMenu) {
        for device in model.devices.value {
            if let light = device as? LIFXLight {
                light.getState()
            }
        }
        updateMenu()
    }
}

extension Reactive where Base: NSMenuItem {
    var titleValue: BindingTarget<String> {
        return BindingTarget(on: UIScheduler(), lifetime: lifetime, setter: { [weak base = self.base] value in
            if let base = base {
                base.title = value
            }
        })
    }
}
