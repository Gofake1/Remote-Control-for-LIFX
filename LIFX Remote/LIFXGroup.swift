//
//  LIFXGroup.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 1/3/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import ReactiveSwift
import Foundation

class LIFXGroup: NSObject {

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

    private(set) var id: String
    private(set) var name: MutableProperty<String>
    private(set) var devices = MutableProperty<[LIFXDevice]>([])
    private(set) var power = MutableProperty(LIFXDevice.PowerState.enabled)
    private(set) var color = MutableProperty<LIFXLight.Color?>(nil)
    @objc dynamic var isHidden = false
    private var addresses = [Address]()
    private static var names = NumberedNameSequence()

    override init() {
        super.init()
        self.id = String(Date().timeIntervalSince1970)
        self.name = MutableProperty(LIFXGroup.names.next())
    }

    init(csvLine: CSV.Line) {
        super.init()
        self.id = csvLine.values[1]
        self.name = MutableProperty(csvLine.values[2])
        guard csvLine.values.count >= 3 else { return }
        csvLine.values[3..<csvLine.values.count].forEach {
            if let address = Address($0) {
                self.addresses.append(address)
            }
        }
    }

    static func ==(lhs: LIFXGroup, rhs: LIFXGroup) -> Bool {
        return lhs.id == rhs.id
    }

//    func restore() {
//        addresses.forEach {
//            if let device = LIFXModel.shared.device(for: $0) {
//                add(device: device)
//            }
//        }
//    }

    func device(at index: Int) -> LIFXDevice {
        return devices.value[index]
    }

    func add(device: LIFXDevice) {
        devices.value.append(device)
    }

    func remove(device: LIFXDevice) {
        if let index = devices.value.index(of: device) {
            devices.value.remove(at: index)
        }
    }

    func setPower(_ power: LIFXDevice.PowerState) {
        self.power.value = power
        devices.value.forEach { $0.setPower(power) }
    }

    func setColor(_ color: LIFXLight.Color) {
        self.color.value = color
        devices.value.forEach { ($0 as? LIFXLight)?.setColor(color) }
    }

    func reset() {
        devices.value = []
    }
}

extension LIFXGroup: CSVEncodable {
    var csvString: String {
        var csvLine = CSV.Line("group", id, name.value)
        for device in devices.value {
            csvLine.append(String(device.address))
        }
        return csvLine.csvString
    }
}
