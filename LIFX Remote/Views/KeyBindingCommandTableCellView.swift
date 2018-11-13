//
//  KeyBindingCommandTableCellView.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 10/9/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa

private let powerMenu: NSMenu = {
    let menu = NSMenu(title: "Power")
    menu.addItem(NSMenuItem(title: "On", action: nil, keyEquivalent: ""))
    menu.addItem(NSMenuItem(title: "Off", action: nil, keyEquivalent: ""))
    return menu
}()

/// A type that can be used as the target in a key binding
protocol KeyBindingCommandTargetType: class {
    var keyBindingCommandTargetSavedState: (kind: KeyBinding.CommandTargetKind, id: String) { get }
    /// - postcondition: Caller is responsible for unbinding and releasing `representedObject`
    func newCommandTargetMenuItem() -> NSMenuItem
}

extension LIFXDevice: KeyBindingCommandTargetType {
    var keyBindingCommandTargetSavedState: (kind: KeyBinding.CommandTargetKind, id: String) {
        return (.device, String(address))
    }

    func newCommandTargetMenuItem() -> NSMenuItem {
        let menuItem = NSMenuItem()
        menuItem.bind(.title, to: self, withKeyPath: #keyPath(LIFXDevice.label), options: nil)
        menuItem.representedObject = self
        return menuItem
    }
}

extension LIFXDeviceGroup: KeyBindingCommandTargetType {
    var keyBindingCommandTargetSavedState: (kind: KeyBinding.CommandTargetKind, id: String) {
        return (.group, id)
    }
    
    func newCommandTargetMenuItem() -> NSMenuItem {
        let menuItem = NSMenuItem()
        menuItem.bind(.title, to: self, withKeyPath: #keyPath(LIFXDeviceGroup.name), options: nil)
        menuItem.representedObject = self
        return menuItem
    }
}

class KeyBindingCommandTableCellView: NSTableCellView {
    @IBOutlet weak var commandTargetPopUpButton: NSPopUpButton!

    lazy var brightnessSlider: NSSlider = {
        let slider = NSSlider(frame: NSRect(x: 268, y:3, width: 72, height: 18))
        slider.minValue = 0.0
        slider.maxValue = 100.0
        slider.allowsTickMarkValuesOnly = true
        slider.numberOfTickMarks = 11
        slider.controlSize = .small
        addSubview(slider)
        return slider
    }()
    lazy var colorWell: NSColorWell = {
        let colorWell = NSColorWell(frame: NSRect(x: 268, y: 1, width: 40, height: 22))
        addSubview(colorWell)
        return colorWell
    }()
    lazy var powerPopUpButton: NSPopUpButton = {
        let popUpButton = NSPopUpButton(frame: NSRect(x: 265, y: 0, width: 60, height: 22))
        popUpButton.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        popUpButton.menu = powerMenu.copy() as? NSMenu
        popUpButton.controlSize = .small
        addSubview(popUpButton)
        return popUpButton
    }()

    override var objectValue: Any? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.unbindControls()
                guard let keyBinding = self?.objectValue as? KeyBinding else { return }
                self?.bindControls(to: keyBinding)
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        commandTargetPopUpButton.menu = KeyBindingCommandTargetMenuFactory.vend()
        NotificationCenter.default.addObserver(self, selector: #selector(devicesChanged),
                                               name: .devicesChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(groupsChanged),
                                               name: .groupsChanged, object: nil)
    }

    @objc func devicesChanged() {
        KeyBindingCommandTargetMenuFactory.updateMenu(commandTargetPopUpButton.menu!,
                                                      for: Model.shared.devices,
                                                      insertionIndex: Model.shared.groups.count)
    }

    @objc func groupsChanged() {
        KeyBindingCommandTargetMenuFactory.updateMenu(commandTargetPopUpButton.menu!,
                                                      for: Model.shared.groups,
                                                      insertionIndex: 0)
    }

    private func bindControls(to keyBinding: KeyBinding) {
        commandTargetPopUpButton.bind(.selectedObject, to: keyBinding,
                                      withKeyPath: #keyPath(KeyBinding.commandTargetObject),
                                      options: nil)
        brightnessSlider.bind(.value, to: keyBinding,
                              withKeyPath: #keyPath(KeyBinding.commandActionBrightnessValue),
                              options: nil)
        brightnessSlider.bind(.hidden, to: keyBinding,
                              withKeyPath: #keyPath(KeyBinding.commandActionIndex),
                              options: [.valueTransformerName: "NotEqualTo0"])
        colorWell.bind(.value, to: keyBinding,
                       withKeyPath: #keyPath(KeyBinding.commandActionColorValue),
                       options: nil)
        colorWell.bind(.hidden, to: keyBinding,
                       withKeyPath: #keyPath(KeyBinding.commandActionIndex),
                       options: [.valueTransformerName: "NotEqualTo1"])
        powerPopUpButton.bind(.selectedIndex, to: keyBinding,
                              withKeyPath: #keyPath(KeyBinding.commandActionPowerValueIndex),
                              options: nil)
        powerPopUpButton.bind(.hidden, to: keyBinding,
                              withKeyPath: #keyPath(KeyBinding.commandActionIndex),
                              options: [.valueTransformerName: "NotEqualTo2"])
    }

    private func unbindControls() {
        commandTargetPopUpButton.unbind(.selectedObject)
        brightnessSlider.unbind(.value)
        brightnessSlider.unbind(.hidden)
        colorWell.unbind(.value)
        colorWell.unbind(.hidden)
        powerPopUpButton.unbind(.selectedIndex)
        powerPopUpButton.unbind(.hidden)
    }

    deinit {
        unbindControls()
        brightnessSlider.removeFromSuperview()
        colorWell.removeFromSuperview()
        powerPopUpButton.removeFromSuperview()
    }
}

struct KeyBindingCommandTargetMenuFactory {
    static func vend() -> NSMenu {
        let menu = NSMenu()
        updateMenu(menu, for: Model.shared.groups, insertionIndex: 0)
        updateMenu(menu, for: Model.shared.devices, insertionIndex: Model.shared.groups.count)
        return menu
    }

    static func updateMenu<T: NSObject & KeyBindingCommandTargetType>(_ menu: NSMenu, for commandTargets: [T],
                                                                      insertionIndex: Int)
    {
        DispatchQueue.main.async {
            // Remove menu items for removed command targets
            var removedMenuItems = [NSMenuItem]()
            for menuItem in menu.items {
                // Ignore command targets of other concrete types
                guard let commandTarget = menuItem.representedObject as? T else { continue }
                if !commandTargets.contains(where: { return $0 == commandTarget }) {
                    removedMenuItems.append(menuItem)
                }
            }
            for menuItem in removedMenuItems {
                menuItem.unbind(.title)
                menuItem.representedObject = nil
                menu.removeItem(menuItem)
            }
            // Add menu items for new command targets
            for (index, commandTarget) in commandTargets.enumerated() {
                if menu.indexOfItem(withRepresentedObject: commandTarget) == -1 {
                    let menuItem = commandTarget.newCommandTargetMenuItem()
                    menu.insertItem(menuItem, at: insertionIndex+index)
                }
            }
        }
    }
}
