//
//  StatusMenuController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 7/13/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa
import ReactiveSwift

class StatusMenuController: NSObject {
    
    enum StatusMessage: String {
        case normal  = "LIFX: Normal"
        case offline = "LIFX: Offline"
    }

    enum ToggleAllMessage: String {
        case on  = "Turn On All Lights"
        case off = "Turn Off All Lights"

        mutating func flip() {
            self = (self == .on) ? .off : .on
        }
    }
    
    @IBOutlet var statusMenu:            NSMenu!
    @IBOutlet var statusMessageMenuItem: NSMenuItem!
    @IBOutlet var toggleAllMenuItem:     NSMenuItem!
    @IBOutlet var placeholderMenuItem:   NSMenuItem!
    fileprivate let model        = LIFXModel.shared
    private let statusItem       = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var menuItems        = [AnyHashable:NSMenuItem]()
    private let statusMessage    = MutableProperty<StatusMessage>(.normal)
    private let toggleAllMessage = MutableProperty<ToggleAllMessage>(.on)
    
    override func awakeFromNib() {
        statusItem.image = #imageLiteral(resourceName: "StatusBarButtonImage")
        model.network.error.producer.startWithSignal {
            $0.0.observeResult {
                switch $0 {
                case .success(let networkError):
                    switch networkError {
                    case .none:
                        self.statusMessage.value = .normal
                    case .offline:
                        self.statusMessage.value = .offline
                    }
                case .failure:
                    break
                }
            }
        }
        statusMessageMenuItem.reactive.titleValue <~ statusMessage.map { return $0.rawValue }
        toggleAllMenuItem.reactive.isEnabled <~ model.devices.map { return $0.count > 0 }
        toggleAllMenuItem.reactive.titleValue <~ toggleAllMessage.map { return $0.rawValue }
        placeholderMenuItem.reactive.isHidden <~ model.devices.map { return $0.count > 0 }
        statusItem.menu = statusMenu

        //model.restoreGroups()
        model.onDiscovery { self.updateMenu() }
        model.discover()
    }
    
    func updateMenu() {
        // Remove menu items that don't have a corresponding group or device after model update
        for (object, menuItem) in menuItems {
            switch object {
            case let object as LIFXGroup:
                if model.groups.value.contains(object) { continue }
            case let object as LIFXDevice:
                if model.devices.value.contains(object) { continue }
            default: continue
            }
            statusMenu.removeItem(menuItem)
            menuItems[object] = nil
        }

        for array in [model.groups.value, model.devices.value] as [[AnyHashable]] {
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
                if model.itemVisibility[item] != true {
                    continue
                }
                // Add new menu items for new groups and devices after model update
                let menuItemController = StatusMenuItemViewController()
                var index: Int
                switch item {
                case let group as LIFXGroup:
                    menuItemController.item = Either.left(group)
                    index = statusMenu.index(of: placeholderMenuItem)
                case let device as LIFXDevice:
                    menuItemController.item = Either.right(device)
                    index = statusMenu.index(of: placeholderMenuItem) + 1
                default: continue
                }
                let menuItem = NSMenuItem()
                menuItem.representedObject = menuItemController
                menuItem.view = menuItemController.view
                //menuItem.target = self
                //menuItem.action = #selector(doNothing(_:))
                statusMenu.insertItem(menuItem, at: index)
                menuItems[item] = menuItem
            }
        }
    }

    // Needed so that validateMenuItem() returns true and allows HighlightingView to draw
    //func doNothing(_ sender: NSMenuItem) {}
    
    @IBAction func toggleAllLights(_ sender: NSMenuItem) {
        model.changeAllDevices(power: (toggleAllMessage.value == .on) ? .enabled : .standby)
        toggleAllMessage.value.flip()
    }
}

extension StatusMenuController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        updateMenu()
        for device in model.devices.value {
            if let light = device as? LIFXLight {
                light.getState()
            }
        }
    }
}

extension Reactive where Base: NSMenuItem {

    var isEnabled: BindingTarget<Bool> {
        return BindingTarget(on: UIScheduler(), lifetime: lifetime, action: { [weak base = self.base] value in
            if let base = base {
                base.isEnabled = value
            }
        })
    }

    var isHidden: BindingTarget<Bool> {
        return BindingTarget(on: UIScheduler(), lifetime: lifetime, action: { [weak base = self.base] value in
            if let base = base {
                base.isHidden = value
            }
        })
    }

    var titleValue: BindingTarget<String> {
        return BindingTarget(on: UIScheduler(), lifetime: lifetime, action: { [weak base = self.base] value in
            if let base = base {
                base.title = value
            }
        })
    }
}
