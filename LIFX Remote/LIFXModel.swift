//
//  LIFXModel.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 6/17/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Foundation

let notificationDevicesChanged = NSNotification.Name(rawValue: "net.gofake1.devicesChangedKey")
let notificationGroupsChanged  = NSNotification.Name(rawValue: "net.gofake1.groupsChangedKey")

enum SavedStateError: Error {
    case unknownVersionFormat
    case illegalValue
}

private func savedStateVersion(_ line: CSV.Line) throws -> Int {
    guard line.values.count == 2, line.values[0] == "version"
        else { throw SavedStateError.unknownVersionFormat }
    guard let version = Int(line.values[1]),
        version == 1 || version == 2 || version == 3
        else { throw SavedStateError.illegalValue }
    return version
}

class LIFXModel: NSObject {
    static let shared: LIFXModel = {
        let model = LIFXModel()
        model.groups.forEach { $0.restore(from: model) }
        model.keyBindings.forEach { $0.restore(from: model) }
        return model
    }()
    private static let savedStateCSVPath =
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SavedState")
            .appendingPathExtension("csv")
            .path
    @objc dynamic var devices = [LIFXDevice]() {
        didSet {
            NotificationCenter.default.post(name: notificationDevicesChanged, object: self)
        }
    }
    @objc dynamic var groups = [LIFXGroup]() {
        didSet {
            NotificationCenter.default.post(name: notificationGroupsChanged, object: self)
        }
    }
    @objc dynamic var keyBindings = [KeyBinding]()
    let network = LIFXNetworkController()
    private var networkStatusChangeHandlers: [(LIFXNetworkController.Status) -> Void] = []

    override init() {
        super.init()
        network.receiver.registerForUnknown(newDevice)
        guard let savedStateData = FileManager.default.contents(atPath: LIFXModel.savedStateCSVPath)
            else { return }
        let savedStateCSV = CSV(String(data: savedStateData, encoding: .utf8))
        guard let line = savedStateCSV.lines.first else { return }
        do {
            let version = try savedStateVersion(line)
            for line in savedStateCSV.lines[1...] {
                switch line.values[0] {
                case "device":
                    if let device = LIFXLight(network: network, csvLine: line, version: version) {
                        add(device: device)
                    }
                case "group":
                    add(group: LIFXGroup(csvLine: line, version: version))
                case "hotkey":
                    add(keyBinding: KeyBinding(csvLine: line, version: version))
                default:
                    break
                }
            }
        #if DEBUG
            let info = """
            Saved state version: \(version)
            Saved devices: \(devices)
            Saved groups: \(groups)
            Saved key bindings: \(keyBindings)
            """
            print(info)
        #endif
        } catch let error {
            print(error)
        }
    }

    func device(for address: Address) -> LIFXDevice? {
        return devices.first { return $0.address == address }
    }

    func group(for id: String) -> LIFXGroup? {
        return groups.first { return $0.id == id }
    }

    func add(device: LIFXDevice) {
        devices.append(device)
    }

    func add(group: LIFXGroup) {
        groups.append(group)
    }

    func add(keyBinding: KeyBinding) {
        keyBindings.append(keyBinding)
    }

    func remove(deviceIndex index: Int) {
        groups.forEach {
            $0.remove(device: devices[index])
        }
        devices[index].willBeRemoved()
        devices.remove(at: index)
    }

    func remove(groupIndex index: Int) {
        groups[index].willBeRemoved()
        groups.remove(at: index)
    }

    func remove(keyBindingIndex index: Int) {
        keyBindings[index].willBeRemoved()
        keyBindings.remove(at: index)
    }

    func changeAllDevices(power: LIFXDevice.PowerState) {
        devices.forEach { $0.setPower(power) }
    }
    
    func discover() {
        devices.forEach { $0.isReachable = false }
        network.send(Packet(type: DeviceMessage.getService))
    }

    func newDevice(_ type: UInt16, _ address: Address, _ response: [UInt8], _ ipAddress: String) {
        guard type == DeviceMessage.stateService.rawValue else { return }
        // Sanity check
        if devices.contains(where: { return $0.address == address }) {
        #if DEBUG
            print("DEVICE ALREADY FOUND: \(address)")
        #endif
            return
        }

        let light = LIFXLight(network: network, address: address, label: nil)
        light.service = LIFXDevice.Service(rawValue: response[0]) ?? .udp
        light.port = UnsafePointer(Array(response[1...4]))
            .withMemoryRebound(to: UInt32.self, capacity: 1, { $0.pointee })
        light.ipAddress = ipAddress
        light.getState()
        light.getVersion()

        add(device: light)
    }

    func onNetworkStatusChange(_ handler: @escaping (LIFXNetworkController.Status) -> Void) {
        networkStatusChangeHandlers.append(handler)
    }

    // Version 1:
    // - "device" address label
    // - "group" id name device_address...
    // Version 2:
    // - "device" address label isVisible
    // - "group" id name isVisible device_address...
    // Version 3:
    // - "hotkey" "device"|"group" address|id keyCode modifiers (action ↓)
    //   - "power" "on"|"off"
    //   - "color" rgb
    //   - "brightness" 0-100
    //   - "temperature" 0-100
    /// Write devices and groups to CSV file
    func saveState() {
        let savedStateCSV = CSV()
        savedStateCSV.append(line: CSV.Line("version", "3"))
        devices.encodeCSV(appendTo: savedStateCSV)
        groups.encodeCSV(appendTo: savedStateCSV)
        keyBindings.encodeCSV(appendTo: savedStateCSV)
        do { try savedStateCSV.write(to: LIFXModel.savedStateCSVPath) }
        catch { fatalError("Failed to write saved state") }
    }
}

extension LIFXModel: LIFXNetworkControllerDelegate {
    func networkStatusChanged(_ newStatus: LIFXNetworkController.Status) {
        networkStatusChangeHandlers.forEach { $0(newStatus) }
    }
}
