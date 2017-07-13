//
//  StatusMenuController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 7/13/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa

protocol NSMenuItemRepresentable: class {
    var isVisible: Bool { get set }
    var menuItem: NSMenuItem { get set }
}

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

    private var deviceMenuItems  = [LIFXDevice: NSMenuItem]()
    private var groupMenuItems   = [LIFXGroup: NSMenuItem]()
    private var toggleAllMessage = ToggleAllMessage.on {
        didSet {
            toggleAllMenuItem.title = toggleAllMessage.rawValue
        }
    }
    private let model = LIFXModel.shared
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    
    override func awakeFromNib() {
        statusItem.image = #imageLiteral(resourceName: "StatusBarButtonImage")
        statusItem.menu = statusMenu

        model.onStatusChange { [weak self] status in
            self?.statusMessageMenuItem.title = statusMessages[status]!
        }
        model.onDevicesCountChange { [weak self] count in
            self?.toggleAllMenuItem.isEnabled = count > 0
            self?.placeholderMenuItem.isHidden = count > 0
        }
        model.discover()

        toggleAllMenuItem.isEnabled = model.devices.count > 0
        placeholderMenuItem.isHidden = model.devices.count > 0
    }

    private func updateVisibility(_ representables: [NSMenuItemRepresentable], insertionIndex: Int) {
        for (index, representable) in representables.enumerated() {
            if !representable.isVisible {
                // `NSMenuItem.isHidden` doesn't work if `NSMenuItem` has custom view
                statusMenu.removeItem(representable.menuItem)
            } else if representable.isVisible && statusMenu.index(of: representable.menuItem) == -1 {
                statusMenu.insertItem(representable.menuItem, at: insertionIndex+index)
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
        updateVisibility(model.groups, insertionIndex: statusMenu.index(of: placeholderMenuItem))
        updateVisibility(model.devices, insertionIndex: statusMenu.index(of: placeholderMenuItem)+1)
        for device in model.devices {
            if let light = device as? LIFXLight {
                light.getState()
            }
        }
    }
}
