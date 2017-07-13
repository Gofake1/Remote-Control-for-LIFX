//
//  LIFXGroup.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 1/3/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Foundation

let notificationGroupNameChanged = NSNotification.Name(rawValue: "net.gofake1.groupNameChangedKey")

class LIFXGroup: NSObject, HudRepresentable, NSMenuItemRepresentable {

    struct NumberedNameSequence {
        var count: Int = 1

        mutating func next() -> String {
            defer { count += 1 }
            return "Group \(count)"
        }
    }

    override var hashValue: Int {
        return id.hashValue
    }

    private static var names = NumberedNameSequence()
    @objc dynamic var devices = [LIFXDevice]() // TODO: NSHashMap for weak references
    var color: LIFXLight.Color?
    var hudController: HudController
    var hudTitle: String {
        return name
    }
    /// Visibility in status menu
    @objc dynamic var isVisible = true
    var menuItem: NSMenuItem
    @objc dynamic var name: String {
        didSet {
            NotificationCenter.default.post(name: notificationGroupNameChanged, object: self)
        }
    }
    var power = LIFXDevice.PowerState.enabled
    let id: String
    private let model = LIFXModel.shared

    override init() {
        self.id = String(Date().timeIntervalSince1970)
        self.name = LIFXGroup.names.next()
        hudController = HudController()
        menuItem = NSMenuItem()
        super.init()
        makeControllers()
    }

    init(csvLine: CSV.Line) {
        self.id = csvLine.values[1]
        self.name = csvLine.values[2]
        hudController = HudController()
        menuItem = NSMenuItem()
        super.init()
        guard csvLine.values.count >= 3 else { return }
        csvLine.values[3..<csvLine.values.count].forEach {
            if let address = Address($0), let device = model.device(for: address) {
                devices.append(device)
            }
        }
        makeControllers()
    }

    func makeControllers() {
        hudController.representable = self
        
        let hudViewController = GroupHudViewController()
        hudViewController.group = self
        hudController.contentViewController = hudViewController

        let menuItemViewController = GroupMenuItemViewController()
        menuItemViewController.group = self
        menuItem.representedObject = menuItemViewController
        menuItem.view = menuItemViewController.view
    }

    static func ==(lhs: LIFXGroup, rhs: LIFXGroup) -> Bool {
        return lhs.id == rhs.id
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

    deinit {
        hudController.close()
        menuItem.menu?.removeItem(menuItem)
    }
}

extension LIFXGroup: CSVEncodable {
    var csvString: String {
        var csvLine = CSV.Line("group", id, name)
        for device in devices {
            csvLine.append(String(device.address))
        }
        return csvLine.csvString
    }
}
