//
//  StatusMenuController.swift
//  LIFX Remote
//
//  Created by David Wu on 7/13/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa

class StatusMenuController: NSObject, NSMenuDelegate {
    
    enum StatusMessage: String {
        case normal    = "LIFX: Normal"
        case searching = "LIFX: Looking for Devices..."
    }
    
    enum ToggleAllState: String {
        case turnOn  = "Turn On All Lights"
        case turnOff = "Turn Off All Lights"
    }
    
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var statusMessageMenuItem: NSMenuItem!
    @IBOutlet weak var toggleAllMenuItem:     NSMenuItem!
    @IBOutlet weak var placeholderMenuItem:   NSMenuItem!
    private let statusItem      = NSStatusBar.system().statusItem(withLength: NSSquareStatusItemLength)
    private var deviceMenuItems = [LIFXDevice:NSMenuItem]()
    private var model           = LIFXModel()
    private var statusMessage   = StatusMessage.normal {
        didSet {
            statusMessageMenuItem.title = statusMessage.rawValue
        }
    }
    private var toggleAllState: ToggleAllState {
        for device in model.devices {
            if device.power == .enabled {
                return .turnOff
            }
        }
        return .turnOn
    }
    private var preferences = PreferencesWindowController()
    
    override func awakeFromNib() {
        statusItem.image            = NSImage(named: "StatusBarButtonImage")
        statusMessageMenuItem.title = statusMessage.rawValue
        toggleAllMenuItem.title     = toggleAllState.rawValue
        statusItem.menu             = statusMenu
        
        model.onDiscovery {
            self.updateMenu()
        }
        model.discover()
    }
    
    private func updateMenu() {
        // Remove menu items that don't have a corresponding device after model update
        for (oldDevice, menuItem) in deviceMenuItems {
            if !model.devices.contains(oldDevice) {
                statusMenu.removeItem(menuItem)
                deviceMenuItems[oldDevice] = nil
            }
        }
        
        if model.devices.count > 0 {
            placeholderMenuItem.isHidden = true
            for device in model.devices {
                // Skip existing menu item views
                if deviceMenuItems[device] != nil {
                    continue
                }
                // Add new menu items for new devices after model update
                let menuItemController = StatusMenuItemViewController()
                menuItemController.device = device
                let menuItem = NSMenuItem()
                menuItem.representedObject = menuItemController
                menuItem.view   = menuItemController.view
                menuItem.target = self
                menuItem.action = #selector(doNothing(_:))
                statusMenu.insertItem(menuItem, at: statusMenu.index(of: placeholderMenuItem))
                deviceMenuItems[device] = menuItem
                model.onUpdate(device: device, {
                    print("model: device update\n")
                    (self.deviceMenuItems[device]?.representedObject as!
                        StatusMenuItemViewController).updateViews()
                })
            }
        } else {
            toggleAllMenuItem.isEnabled  = false
            placeholderMenuItem.isHidden = false
        }
    }
    
    // Needed so that validateMenuItem() returns true and allows HighlightingView to draw highlight
    func doNothing(_ sender: NSMenuItem) {}
    
    @IBAction func toggleAllLights(_ sender: NSMenuItem) {
        model.changeAllDevices(state: toggleAllState == .turnOn ? LIFXDevice.PowerState.enabled :
                                                                  LIFXDevice.PowerState.standby)
        toggleAllMenuItem.title = toggleAllState.rawValue
    }
    
    @IBAction func showPreferences(_ sender: NSMenuItem) {
        preferences.model = model
        preferences.showWindow(nil)
    }
    
    // MARK: - NSMenuDelegate
    
    func menuWillOpen(_ menu: NSMenu) {
        for device in model.devices {
            if let light = device as? LIFXLight {
                light.getState()
            }
        }
        updateMenu()
    }

}
