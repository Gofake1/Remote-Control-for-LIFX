//
//  LIFXDeviceGroup.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 1/3/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa

final class LIFXDeviceGroup: NSObject, HudRepresentable, StatusMenuItemRepresentable {
    override var description: String {
        return "group: { name: \(name), devices: \(devices) }"
    }
    private static var names = NumberedNameSequence()
    var color = LIFXLight.Color(nsColor: NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)) {
        didSet { NotificationCenter.default.post(name: .groupColorChanged, object: self) }
    }
    @objc dynamic var devices = [LIFXDevice]()
    var hudController = HudController()
    var hudTitle: String {
        return name
    }
    /// Visibility in status menu
    @objc dynamic var isVisible = true
    var statusMenuItem = NSMenuItem()
    @objc dynamic var name: String {
        didSet { NotificationCenter.default.post(name: .groupNameChanged, object: self) }
    }
    var power = LIFXDevice.PowerState.enabled {
        didSet { NotificationCenter.default.post(name: .groupPowerChanged, object: self) }
    }
    let id: String

    override init() {
        id = String(Date().timeIntervalSince1970)
        name = LIFXDeviceGroup.names.next()
        super.init()
        makeControllers()
    }
    
    init(id: String, name: String, devices: [LIFXDevice], isVisible: Bool) {
        self.id = id
        self.name = name
        self.devices = devices
        self.isVisible = isVisible
        super.init()
        makeControllers()
    }

    func makeControllers() {
        hudController.representable = self
        let hudViewController = GroupHudViewController()
        hudViewController.group = self
        hudController.contentViewController = hudViewController

        let menuItemViewController = GroupMenuItemViewController()
        menuItemViewController.group = self
        statusMenuItem.representedObject = menuItemViewController
        statusMenuItem.view = menuItemViewController.view
    }

    func device(at index: Int) -> LIFXDevice {
        return devices[index]
    }

    func add(device: LIFXDevice) {
        devices.append(device)
    }

    func remove(device: LIFXDevice) {
        if let index = devices.index(of: device) {
            devices.remove(at: index)
        }
    }

    func setPower(_ power: LIFXDevice.PowerState) {
        self.power = power
        devices.forEach { $0.setPower(power) }
    }

    func setColor(_ color: LIFXLight.Color) {
        self.color = color
        devices.forEach { ($0 as? LIFXLight)?.setColor(color) }
    }

    func willBeRemoved() {
        hudController.close()
        statusMenuItem.menu?.removeItem(statusMenuItem)
        devices.removeAll()
    }
}

extension LIFXDeviceGroup: CSVEncodable {
    var csvLine: CSV.Line? {
        var line = CSV.Line("group", id, name, isVisible ? "visible" : "hidden")
        for device in devices {
            line.append(String(device.address))
        }
        return line
    }
}

extension LIFXDeviceGroup {
    struct NumberedNameSequence {
        var count: Int = 1
        
        mutating func next() -> String {
            defer { count += 1 }
            return "Group \(count)"
        }
    }
}

extension Notification.Name {
    static let groupColorChanged = Notification.Name("net.gofake1.LIFX-Remote.groupColorChanged")
    static let groupNameChanged  = Notification.Name("net.gofake1.LIFX-Remote.groupNameChanged")
    static let groupPowerChanged = Notification.Name("net.gofake1.LIFX-Remote.groupPowerChanged")
}
