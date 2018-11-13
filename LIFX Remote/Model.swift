//
//  Model.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 6/17/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Foundation

final class Model: NSObject {
    static let shared = Persisting.restore(Model.Decoding()) ?? Model()
    @objc dynamic private(set) var devices = [LIFXDevice]() {
        didSet { NotificationCenter.default.post(name: .devicesChanged, object: nil) }
    }
    @objc dynamic private(set) var groups = [LIFXDeviceGroup]() {
        didSet { NotificationCenter.default.post(name: .groupsChanged, object: nil) }
    }
    @objc dynamic private(set) var keyBindings = [KeyBinding]()
    private let queue = DispatchQueue.main
    
    convenience init(devices: [LIFXDevice], groups: [LIFXDeviceGroup], keyBindings: [KeyBinding]) {
        self.init()
        self.devices = devices
        self.groups = groups
        self.keyBindings = keyBindings
    }
    
    func setup() {
        Logging.log("""
            Saved devices: \(devices)
            Saved groups: \(groups)
            Saved key bindings: \(keyBindings)
            """)
        Networking.listen(for: LIFXPacket.self)
    }
    
    func device(for address: Address) -> LIFXDevice? {
        return devices.first { $0.address == address }
    }
    
    func group(for id: String) -> LIFXDeviceGroup? {
        return groups.first { $0.id == id }
    }
    
    func powerAll(_ power: LIFXDevice.PowerState) {
        queue.async { [weak self] in self!.devices.forEach { $0.setPower(power) }}
    }
    
    func refresh() {
        queue.async { [weak self] in
            self!.devices.forEach { $0.isReachable = false }
            Networking.send(LIFXPacket(kind: .getService))
        }
    }
    
    func add(device: LIFXDevice) {
        queue.async { [weak self] in self!.devices.append(device) }
    }
    
    func add(group: LIFXDeviceGroup) {
        queue.async { [weak self] in self!.groups.append(group) }
    }
    
    func add(keyBinding: KeyBinding) {
        queue.async { [weak self] in self!.keyBindings.append(keyBinding) }
    }
    
    func removeDevice(at index: Int) {
        queue.async { [weak self] in
            self!.groups.forEach { $0.remove(device: self!.devices[index]) }
            self!.devices[index].willBeRemoved()
            self!.devices.remove(at: index)
        }
    }
    
    func removeGroup(at index: Int) {
        queue.async { [weak self] in
            self!.groups[index].willBeRemoved()
            self!.groups.remove(at: index)
        }
    }
    
    func removeKeyBinding(at index: Int) {
        queue.async { [weak self] in
            self!.keyBindings[index].willBeRemoved()
            self!.keyBindings.remove(at: index)
        }
    }
}

extension LIFXPacket {
    enum NewRouteError: Error {
        case addressIsUsed(Address)
        case illegalPacketKind
        case noPayload
    }
    
    func routeNotFound() throws {
        guard header.kind == .stateService else { throw NewRouteError.illegalPacketKind }
        guard Model.shared.device(for: header.target) == nil else { throw NewRouteError.addressIsUsed(header.target) }
        guard let res = payload?.bytes else { throw NewRouteError.noPayload }
        DispatchQueue.main.async { [header, originIpAddress] in
            let light = LIFXLight(address: header.target, label: nil)
            light.service = LIFXDevice.Service(rawValue: res[0]) ?? .udp
            light.port = UnsafePointer(Array(res[1...4])).withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }
            light.ipAddress = originIpAddress!
            Model.shared.add(device: light)
            LIFXPacket.Router.register(light)
            light.getState()
            light.getVersion()
        }
    }
}

extension Notification.Name {
    static let devicesChanged = Notification.Name("net.gofake1.LIFX-Remote.devicesChanged")
    static let groupsChanged  = Notification.Name("net.gofake1.LIFX-Remote.groupsChanged")
}
