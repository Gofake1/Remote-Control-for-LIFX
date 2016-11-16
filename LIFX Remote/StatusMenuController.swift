//
//  StatusMenuController.swift
//  LIFX Remote
//
//  Created by David Wu on 7/13/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa

class StatusMenuController: NSObject {
    
    enum StatusMessage: String {
        case normal    = "LIFX: Normal"
        case error     = "LIFX: Error"
        case searching = "LIFX: Looking for Devices..."
        case none      = "LIFX: No Devices Found"
    }
    
    enum ToggleAllState: String {
        case on  = "Turn On All Lights"
        case off = "Turn Off All Lights"
    }
    
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var statusMessageMenuItem: NSMenuItem!
    @IBOutlet weak var toggleAllMenuItem:     NSMenuItem!
    @IBOutlet weak var placeholderMenuItem:   NSMenuItem!
    private let statusItem      = NSStatusBar.system().statusItem(withLength: NSSquareStatusItemLength)
    private let preferences     = PreferencesWindowController()
    private var model           = LIFXModel()
    private var statusMessage   = StatusMessage.searching {
        didSet {
            statusMessageMenuItem.title = statusMessage.rawValue
        }
    }
    private var toggleAllState  = ToggleAllState.on
    private var deviceMenuItems = [LIFXDevice:NSMenuItem]()
    
    override func awakeFromNib() {
        statusItem.image            = NSImage(named: "StatusBarButtonImage")
        statusMessageMenuItem.title = statusMessage.rawValue
        toggleAllMenuItem.title     = toggleAllState.rawValue
        statusItem.menu             = statusMenu
        
        model.scan {
            self.updateMenu()
            self.statusMessage = .normal
        }
    }
    
    private func updateMenu() {
        if model.devices.count > 0 {
            placeholderMenuItem.isHidden = true
            // Remove menu items that don't have a corresponding device after model update
            for (oldDevice, menuItem) in deviceMenuItems {
                if !model.devices.contains(oldDevice) {
                    statusMenu.removeItem(menuItem)
                    deviceMenuItems[oldDevice] = nil
                }
            }
            // Add new menu items for new devices after model update
            for device in model.devices {
                if deviceMenuItems[device] != nil {
                    continue
                }
                let menuItemController = StatusMenuItemViewController()
                menuItemController.device = device
                let menuItem = NSMenuItem()
                menuItem.representedObject = menuItemController
                menuItem.view   = menuItemController.view
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
    
    // Needed so that validateMenuItem: returns true and allows HighlightingView to draw highlight
    func doNothing(_ sender: NSMenuItem) {}
    
    @IBAction func toggleAllLights(_ sender: NSMenuItem) {
        switch toggleAllState {
        case .on:
            toggleAllState = .off
        case .off:
            toggleAllState = .on
        }
        model.changeAllDevices(state: (toggleAllState == .on ? LIFXDevice.PowerState.on : LIFXDevice.PowerState.off))
        toggleAllMenuItem.title = toggleAllState.rawValue
    }
    
    @IBAction func showPreferences(_ sender: NSMenuItem) {
        preferences.showWindow(nil)
    }

}
