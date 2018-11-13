//
//  Persisting.swift
//  Remote Control for LIFX
//
//  Created by David on 4/1/18.
//  Copyright © 2018 Gofake1. All rights reserved.
//

import AppKit

final class Persisting {
    static func restore<T: DecodingContext>(_ context: T) -> T.Decoded? {
        do { return try context.decode() } catch { Logging.log(error) }
        return nil
    }
    
    static func persist(_ context: EncodingContext) {
        do { try context.encode() } catch { Logging.log(error) }
    }
}

protocol DecodingContext {
    associatedtype Decoded
    func decode() throws -> Decoded
}

protocol EncodingContext {
    func encode() throws
}

protocol DummyType {}

extension Model {
    final class Decoding {
        enum DecodeError: Error {
            case noData
            case unknownVersion
            case unknownFormat
        }
    }
    
    fileprivate static let filePath =
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SavedState").appendingPathExtension("csv").path
}

extension Model.Decoding: DecodingContext {
    typealias Decoded = Model
    func decode() throws -> Decoded {
        func parseVersion(from line: CSV.Line) throws -> Int {
            guard line.values.count == 2, line.values[0] == "version" else { throw DecodeError.unknownFormat }
            guard let version = Int(line.values[1]), version >= 1, version <= 3
                else { throw DecodeError.unknownVersion }
            return version
        }
        
        func makeDummy(_ line: CSV.Line, _ version: Int) -> DummyType? {
            switch line.values[0] {
            case "device":  return LIFXDevice.Dummy(line: line, version: version)
            case "group":   return LIFXDeviceGroup.Dummy(line: line, version: version)
            case "hotkey":  return KeyBinding.Dummy(line: line, version: version)
            default:        return nil
            }
        }
        
        func makeDevice(_ dummy: LIFXDevice.Dummy) -> LIFXDevice {
            return LIFXDevice(address: dummy.address, label: dummy.label, isVisible: dummy.isVisible)
        }
        
        func makeGroup(_ dummy: LIFXDeviceGroup.Dummy, _ mapping: [Address: [LIFXDevice]]) -> LIFXDeviceGroup {
            let devices = dummy.deviceAddresses.compactMap { mapping[$0]?.first }
            return LIFXDeviceGroup(id: dummy.id, name: dummy.name, devices: devices, isVisible: dummy.isVisible)
        }
        
        func makeKeyBinding(_ dummy: KeyBinding.Dummy, _ deviceMapping: [Address: [LIFXDevice]],
                            _ groupMapping: [String: [LIFXDeviceGroup]]) -> KeyBinding?
        {
            let target: AnyObject
            switch dummy.targetKind {
            case .device:
                guard let address = Address(dummy.targetValue),
                    let device = deviceMapping[address]?.first
                    else { return nil }
                target = device
            case .group:
                guard let group = groupMapping[dummy.targetValue]?.first else { return nil }
                target = group
            }
            return KeyBinding(target: target, action: dummy.actionKind, actionValue: dummy.actionValue,
                              keyCode: dummy.keyCode, modifierFlags: dummy.modifierFlags)
        }
        
        guard let data = FileManager.default.contents(atPath: Model.filePath) else { throw DecodeError.noData }
        let csv = CSV(String(data: data, encoding: .utf8))
        let version = try parseVersion(from: csv.lines[0])
        Logging.log("Saved state version: \(version)")
        var deviceDummies = [LIFXDevice.Dummy]()
        var groupDummies = [LIFXDeviceGroup.Dummy]()
        var keyBindingDummies = [KeyBinding.Dummy]()
        for dummy in csv.lines[1...].compactMap({ makeDummy($0, version) }) {
            switch dummy {
            case let dummy as LIFXDevice.Dummy:
                deviceDummies.append(dummy)
            case let dummy as LIFXDeviceGroup.Dummy:
                groupDummies.append(dummy)
            case let dummy as KeyBinding.Dummy:
                keyBindingDummies.append(dummy)
            default:
                Logging.log("Unknown dummy: \(dummy)")
            }
        }
        let devices = deviceDummies.map(makeDevice)
        let addressToDevice = Dictionary(grouping: devices, by: { $0.address })
        let groups = groupDummies.map { makeGroup($0, addressToDevice) }
        let idToGroup = Dictionary(grouping: groups, by: { $0.id })
        let keyBindings = keyBindingDummies.compactMap { makeKeyBinding($0, addressToDevice, idToGroup) }
        return Model(devices: devices, groups: groups, keyBindings: keyBindings)
    }
}

extension Model: EncodingContext {
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
    func encode() throws {
        let values = ([devices, groups, keyBindings] as [[Any]]).flatMap { $0 }
        let csv = CSV(lines: [CSV.Line("version", "3")] + values.compactMap { ($0 as! CSVEncodable).csvLine } )
        try csv.write(to: Model.filePath)
    }
}

protocol CSVEncodable {
    /// Return `nil` if type should not be encoded
    var csvLine: CSV.Line? { get }
}

class CSV {
    var lines = [Line]()
    
    init(_ document: String? = nil) {
        if let document = document {
            for line in document.components(separatedBy: "\n") {
                self.lines.append(Line(line))
            }
        }
    }
    
    init(lines: [Line]) {
        self.lines = lines
    }
    
    func append(line: Line) {
        lines.append(line)
    }
    
    func append(lineString: String) {
        lines.append(Line(lineString))
    }
    
    func write(to path: String) throws {
        var str = ""
        lines.forEach { str += $0.csvString + "\n" }
        try str.write(toFile: path, atomically: true, encoding: .utf8)
    }
}

extension CSV {
    struct Line {
        var csvString: String {
            return values.joined(separator: ",")
        }
        var values: [String]
        
        init() {
            self.values = []
        }
        
        init(_ string: String) {
            self.values = string.components(separatedBy: ",")
        }
        
        init(_ values: String...) {
            self.values = values
        }
        
        mutating func append(_ value: String) {
            self.values.append(value)
        }
    }
}

extension LIFXDevice {
    fileprivate struct Dummy: DummyType {
        let address: Address
        let isVisible: Bool
        let label: String
        
        init?(line: CSV.Line, version: Int) {
            guard line.values.count >= 3, let address = Address(line.values[1]) else { return nil }
            self.address = address
            label = line.values[2]
            switch version {
            case 1:
                isVisible = true
            case 2: fallthrough
            case 3:
                guard line.values.count >= 4 else { return nil }
                isVisible = line.values[3] == "visible"
            default:
                return nil
            }
        }
    }
}

extension LIFXDeviceGroup {
    struct Dummy: DummyType {
        var deviceAddresses = [Address]()
        let id: String
        let isVisible: Bool
        let name: String
        
        init?(line: CSV.Line, version: Int) {
            guard line.values.count >= 3 else { return nil }
            id = line.values[1]
            name = line.values[2]
            switch version {
            case 1:
                isVisible = true
                guard line.values.count >= 4 else { return }
                line.values[3...].forEach {
                    guard let address = Address($0) else { return }
                    deviceAddresses.append(address)
                }
            case 2: fallthrough
            case 3:
                guard line.values.count >= 4 else { return nil }
                isVisible = line.values[3] == "visible"
                guard line.values.count >= 5 else { return }
                line.values[4...].forEach {
                    guard let address = Address($0) else { return }
                    deviceAddresses.append(address)
                }
            default:
                return nil
            }
        }
    }
}

extension KeyBinding {
    struct Dummy: DummyType {
        let actionKind: KeyBinding.CommandActionKind
        let actionValue: String
        let keyCode: UInt16
        let modifierFlags: NSEvent.ModifierFlags
        let targetKind: KeyBinding.CommandTargetKind
        let targetValue: String
        
        init?(line: CSV.Line, version: Int) {
            guard version >= 3, line.values.count >= 6, let keyCode = UInt16(line.values[3]),
                let modifierFlags = UInt32(line.values[4])?.modifierFlags, Hotkey.validate(keyCode, modifierFlags),
                let targetKind = KeyBinding.CommandTargetKind(rawValue: line.values[1]),
                let actionKind = KeyBinding.CommandActionKind(rawValue: line.values[5])
                else { return nil }
            self.actionKind = actionKind
            actionValue = line.values[2]
            self.keyCode = keyCode
            self.modifierFlags = modifierFlags
            self.targetKind = targetKind
            targetValue = line.values[6]
        }
    }
}
