//
//  StatusMenuController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 7/13/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa

//private let statusMessages: [LIFXNetworkController.Status: String] = [
//    .normal: "Normal",
//    .error:  "Error"
//]

protocol StatusMenuItemRepresentable: class {
    var isVisible: Bool { get set }
    var statusMenuItem: NSMenuItem { get set }
}

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

    @objc private let model = Model.shared
    private var deviceMenuItems  = [LIFXDevice: NSMenuItem]()
    private var groupMenuItems   = [LIFXDeviceGroup: NSMenuItem]()
    private var toggleAllMessage = ToggleAllMessage.on {
        didSet { toggleAllMenuItem.title = toggleAllMessage.rawValue }
    }
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    
    override func awakeFromNib() {
        statusItem.image = #imageLiteral(resourceName: "StatusBarButton")
        statusItem.menu = statusMenu
//        model.onNetworkStatusChange { [weak self] status in
//            self?.statusMessageMenuItem.title = "LIFX: \(statusMessages[status]!)"
//        }
    }

    private func updateVisibility(_ representables: [StatusMenuItemRepresentable], insertionIndex: Int) {
        for (index, representable) in representables.enumerated() {
            if !representable.isVisible {
                guard statusMenu.index(of: representable.statusMenuItem) != -1 else { continue }
                // Workaround: `NSMenuItem.isHidden` doesn't work if `NSMenuItem` has custom view
                statusMenu.removeItem(representable.statusMenuItem)
            } else if representable.isVisible && statusMenu.index(of: representable.statusMenuItem) == -1 {
                statusMenu.insertItem(representable.statusMenuItem, at: insertionIndex+index)
            }
        }
    }
    
    @IBAction func toggleAllLights(_ sender: NSMenuItem) {
        Model.shared.powerAll(toggleAllMessage == .on ? .enabled : .standby)
        toggleAllMessage.flip()
    }
}

extension StatusMenuController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        updateVisibility(Model.shared.groups, insertionIndex: statusMenu.index(of: placeholderMenuItem))
        updateVisibility(Model.shared.devices, insertionIndex: statusMenu.index(of: placeholderMenuItem)+1)
        for device in Model.shared.devices {
            if let light = device as? LIFXLight {
                light.getState()
            }
        }
    }
}
