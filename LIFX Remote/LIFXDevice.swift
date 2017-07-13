//
//  LIFXDevice.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 12/8/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa

typealias Address  = UInt64
typealias Label    = String
typealias Duration = UInt32

let notificationDeviceLabelChanged = NSNotification.Name(rawValue: "net.gofake1.deviceLabelChangedKey")
let notificationDevicePowerChanged = NSNotification.Name(rawValue: "net.gofake1.devicePowerChangedKey")
let notificationDeviceWifiChanged  = NSNotification.Name(rawValue: "net.gofake1.deviceWifiChangedKey")
let notificationDeviceModelChanged = NSNotification.Name(rawValue: "net.gofake1.deviceModelChangedKey")

class LIFXDevice: NSObject, HudRepresentable, NSMenuItemRepresentable {

    enum Service: UInt8 {
        case udp = 1
    }

    enum PowerState: UInt16 {
        case enabled = 65535
        case standby = 0

        var bytes: [UInt8] {
            return [rawValue[0].toU8, rawValue[1].toU8]
        }
    }

    struct WifiInfo {
        var signal:  Float32?
        var tx:      UInt32?
        var rx:      UInt32?
        var build:   UInt64?
        var version: UInt32?
    }

    struct DeviceInfo {

        enum Product: UInt32, CustomStringConvertible {
            case original1000   = 1
            case color650       = 3
            case white800LV     = 10
            case white800HV     = 11
            case white900BR30LV = 18
            case color1000BR30  = 20
            case color1000      = 22
            case lifxA19        = 27
            case lifxBR30       = 28
            case lifxPlusA19    = 29
            case lifxPlusBR30   = 30
            case lifxZ          = 31

            var description: String {
                switch self {
                case .original1000:   return "Original 1000"
                case .color650:       return "Color 650"
                case .white800LV:     return "White 800 LV"
                case .white800HV:     return "White 800 HV"
                case .white900BR30LV: return "White 900 BR30 LV"
                case .color1000BR30:  return "Color 1000 BR30"
                case .color1000:      return "Color 1000"
                case .lifxA19:        return "LIFX A19"
                case .lifxBR30:       return "LIFX BR30"
                case .lifxPlusA19:    return "LIFX + A19"
                case .lifxPlusBR30:   return "LIFX + BR30"
                case .lifxZ:          return "LIFX Z"
                }
            }
        }

        var vendor:  UInt32?
        var product: Product?
        var version: UInt32?
    }

    struct RuntimeInfo {
        var time:     UInt64?
        var uptime:   UInt64?
        var downtime: UInt64?
    }

    struct LocationInfo {
        var location:  [UInt8]?
        var label:     String?
        var updatedAt: UInt64?
    }

    struct GroupInfo {
        var group:     [UInt8]?
        var label:     String?
        var updatedAt: UInt64?
    }

    override var description: String {
        return "device: { label: \(label), address: \(address) }"
    }

    override var hashValue: Int {
        return address.hashValue
    }

    unowned let network: LIFXNetworkController
    var hudController: HudController
    var hudTitle: String {
        return label
    }
    var menuItem: NSMenuItem
    var service = Service.udp
    var port    = UInt32(56700)
    @objc dynamic var ipAddress = "Unknown"
    /// Visibility in status menu
    @objc dynamic var isVisible = true
    @objc dynamic var label = "Unknown" {
        didSet {
            NotificationCenter.default.post(name: notificationDeviceLabelChanged, object: self)
        }
    }
    var power = PowerState.standby {
        didSet {
            NotificationCenter.default.post(name: notificationDevicePowerChanged, object: self)
        }
    }
    var wifiInfo = WifiInfo() {
        didSet {
            NotificationCenter.default.post(name: notificationDeviceWifiChanged, object: self)
        }
    }
    var deviceInfo = DeviceInfo() {
        didSet {
            NotificationCenter.default.post(name: notificationDeviceModelChanged, object: self)
        }
    }
    var runtimeInfo  = RuntimeInfo()
    var locationInfo = LocationInfo()
    var groupInfo    = GroupInfo()
    let address: Address

    init(network: LIFXNetworkController, address: Address, label: Label?) {
        self.network = network
        self.address = address
        self.label   = label ?? "Unknown"
        hudController = HudController()
        menuItem = NSMenuItem()
        super.init()
        makeControllers()
        network.receiver.register(address: address, type: DeviceMessage.stateService) { [weak self] in
            self?.stateService($0)
        }
        network.receiver.register(address: address, type: DeviceMessage.statePower) { [weak self] in
            self?.statePower($0)
        }
        network.receiver.register(address: address, type: DeviceMessage.stateLabel) { [weak self] in
            self?.stateLabel($0)
        }
        network.receiver.register(address: address, type: DeviceMessage.stateHostInfo) { [weak self] in
            self?.stateHostInfo($0)
        }
        network.receiver.register(address: address, type: DeviceMessage.stateHostFirmware) { [weak self] in
            self?.stateHostFirmware($0)
        }
        network.receiver.register(address: address, type: DeviceMessage.stateWifiInfo) { [weak self] in
            self?.stateWifiInfo($0)
        }
        network.receiver.register(address: address, type: DeviceMessage.stateWifiFirmware) { [weak self] in
            self?.stateWifiFirmware($0)
        }
        network.receiver.register(address: address, type: DeviceMessage.stateVersion) { [weak self] in
            self?.stateVersion($0)
        }
        network.receiver.register(address: address, type: DeviceMessage.stateInfo) { [weak self] in
            self?.stateInfo($0)
        }
        network.receiver.register(address: address, type: DeviceMessage.echoResponse) { [weak self] in
            self?.echoResponse($0)
        }
    }

    convenience init(network: LIFXNetworkController, csvLine: CSV.Line) {
        guard let address = UInt64(csvLine.values[1]) else { fatalError() }
        let label = csvLine.values[2]
        self.init(network: network, address: address, label: label)
    }

    static func ==(lhs: LIFXDevice, rhs: LIFXDevice) -> Bool {
        return lhs.address == rhs.address
    }

    func makeControllers() {
        hudController.representable = self

        let hudViewController = DeviceHudViewController()
        hudViewController.device = self
        hudController.contentViewController = hudViewController

        let menuItemViewController = DeviceMenuItemViewController()
        menuItemViewController.device = self
        menuItem.representedObject = menuItemViewController
        menuItem.view = menuItemViewController.view
    }

    func getService() {
        network.send(Packet(type: DeviceMessage.getService, to: address))
    }

    func stateService(_ response: [UInt8]) {
        if let service = Service(rawValue: response[0]) {
            self.service = service
        }
        self.port = UnsafePointer(Array(response[1...4]))
            .withMemoryRebound(to: UInt32.self, capacity: 1, { $0.pointee })
    }

    func getPower() {
        network.send(Packet(type: DeviceMessage.getPower, to: address))
    }

    func setPower(_ power: PowerState, duration: Duration = 1024) {
        self.power = power
        network.send(Packet(type: DeviceMessage.setPower,
                            with: power.bytes + duration.bytes,
                            to:   address))
    }

    func statePower(_ response: [UInt8]) {
        let value = UnsafePointer(response).withMemoryRebound(to: UInt16.self, capacity: 1, { $0.pointee })
        if let power = PowerState(rawValue: value) {
            self.power = power
        }
    }

    func getLabel() {
        network.send(Packet(type: DeviceMessage.getLabel, to: address))
    }

    func setLabel(_ label: Label) {
        self.label = label
        network.send(Packet(type: DeviceMessage.setLabel, with: label.bytes, to: address))
    }

    func stateLabel(_ response: [UInt8]) {
        if let label = String(bytes: response[0...31], encoding: .utf8) {
            self.label = label
        }
    }

    /// Get host signal, tx, rx
    func getHostInfo() {
        network.send(Packet(type: DeviceMessage.getHostInfo, to: address))
    }

    func stateHostInfo(_ response: [UInt8]) {

    }

    /// Get host firmware build, version
    func getHostFirmware() {
        network.send(Packet(type: DeviceMessage.getHostFirmware, to: address))
    }

    func stateHostFirmware(_ response: [UInt8]) {

    }

    /// Get Wifi subsystem signal, tx, rx
    func getWifiInfo() {
        network.send(Packet(type: DeviceMessage.getWifiInfo, to: address))
    }

    func stateWifiInfo(_ response: [UInt8]) {
        wifiInfo.signal = UnsafePointer(Array(response[0...3]))
            .withMemoryRebound(to: Float32.self, capacity: 1, { $0.pointee })
        wifiInfo.tx     = UnsafePointer(Array(response[4...7]))
            .withMemoryRebound(to: UInt32.self, capacity: 1, { $0.pointee })
        wifiInfo.rx     = UnsafePointer(Array(response[8...11]))
            .withMemoryRebound(to: UInt32.self, capacity: 1, { $0.pointee })
    }

    /// Get Wifi subsystem build, version
    func getWifiFirmware() {
        network.send(Packet(type: DeviceMessage.getWifiFirmware, to: address))
    }

    func stateWifiFirmware(_ response: [UInt8]) {
        wifiInfo.build   = UnsafePointer(Array(response[0...7]))
            .withMemoryRebound(to: UInt64.self, capacity: 1, { $0.pointee })
        wifiInfo.version = UnsafePointer(Array(response[16...19]))
            .withMemoryRebound(to: UInt32.self, capacity: 1, { $0.pointee })
    }

    /// Get device hardware vendor, product, version
    func getVersion() {
        network.send(Packet(type: DeviceMessage.getVersion, to: address))
    }

    func stateVersion(_ response: [UInt8]) {
        deviceInfo.vendor  = UnsafePointer(Array(response[0...3]))
            .withMemoryRebound(to: UInt32.self, capacity: 1, { $0.pointee })
        deviceInfo.product = DeviceInfo.Product(rawValue: UnsafePointer(Array(response[4...7]))
            .withMemoryRebound(to: UInt32.self, capacity: 1, { $0.pointee }))
        deviceInfo.version = UnsafePointer(Array(response[8...11]))
            .withMemoryRebound(to: UInt32.self, capacity: 1, { $0.pointee })
    }

    /// Print device time, uptime, downtime
    func getInfo() {
        network.send(Packet(type: DeviceMessage.getInfo, to: address))
    }

    func stateInfo(_ response: [UInt8]) {
        runtimeInfo.time     = UnsafePointer(Array(response[0...8]))
            .withMemoryRebound(to: UInt64.self, capacity: 1, { $0.pointee })
        runtimeInfo.uptime   = UnsafePointer(Array(response[8...16]))
            .withMemoryRebound(to: UInt64.self, capacity: 1, { $0.pointee })
        runtimeInfo.downtime = UnsafePointer(Array(response[16...24]))
            .withMemoryRebound(to: UInt64.self, capacity: 1, { $0.pointee })
    }

    /// Get device location, label, updated_at
    func getLocation() {
        network.send(Packet(type: DeviceMessage.getLocation, to: address))
    }

    func stateLocation(_ response: [UInt8]) {
        locationInfo.location = Array(response[0...15])
        if let label = String(bytes: response[16...47], encoding: .utf8) {
            locationInfo.label = label
        }
        locationInfo.updatedAt = UnsafePointer(Array(response[48...55]))
            .withMemoryRebound(to: UInt64.self, capacity: 1, { $0.pointee })
    }

    /// Get group, label, updated_at
    func getGroup() {
        network.send(Packet(type: DeviceMessage.getGroup, to: address))
    }

    func stateGroup(_ response: [UInt8]) {
        groupInfo.group = Array(response[0...15])
        if let label = String(bytes: response[16...47], encoding: .utf8) {
            groupInfo.label = label
        }
        groupInfo.updatedAt = UnsafePointer(Array(response[48...55]))
            .withMemoryRebound(to: UInt64.self, capacity: 1, { $0.pointee })
    }

    func echoRequest(payload: [UInt8]) {
        network.send(Packet(type: DeviceMessage.echoRequest, with: payload, to: address))
    }

    func echoResponse(_ response: [UInt8]) {
        print("echo:\n\t\(response)\n")
    }

    deinit {
        hudController.close()
        menuItem.menu?.removeItem(menuItem)
        network.receiver.unregister(address)
    }
}

extension LIFXDevice: CSVEncodable {
    var csvString: String {
        return CSV.Line("device", String(address), label).csvString
    }
}

let notificationLightColorChanged = NSNotification.Name(rawValue: "net.gofake1.lightColorChangedKey")

class LIFXLight: LIFXDevice {

    struct Color {

        var hue:        UInt16
        var saturation: UInt16
        var brightness: UInt16
        var kelvin:     UInt16 // 2500° (warm) to 9000° (cool)

        var brightnessAsPercentage: Int {
            return Int(Double(brightness)/Double(UInt16.max) * 100)
        }

        var kelvinAsPercentage: Int {
            return Int((kelvin-2500)/65)
        }

        var bytes: [UInt8] {
            let hue:        [UInt8] = [self.hue[0].toU8       , self.hue[1].toU8       ]
            let saturation: [UInt8] = [self.saturation[0].toU8, self.saturation[1].toU8]
            let brightness: [UInt8] = [self.brightness[0].toU8, self.brightness[1].toU8]
            let kelvin:     [UInt8] = [self.kelvin[0].toU8    , self.kelvin[1].toU8    ]
            return hue + saturation + brightness + kelvin
        }

        var nsColor: NSColor {
            return NSColor(calibratedHue: CGFloat(hue)/CGFloat(UInt16.max),
                           saturation: CGFloat(saturation)/CGFloat(UInt16.max),
                           brightness: CGFloat(brightness)/CGFloat(UInt16.max),
                           alpha: 1.0)
        }

        init(hue: UInt16, saturation: UInt16, brightness: UInt16, kelvin: UInt16) {
            self.hue        = hue
            self.saturation = saturation
            self.brightness = brightness
            self.kelvin     = kelvin
        }

        init(nsColor: NSColor) {
            let r = nsColor.redComponent
            let g = nsColor.greenComponent
            let b = nsColor.blueComponent
            let minRgb = min(r, min(g, b))
            let maxRgb = max(r, max(g, b))
            var hue, saturation, brightness: UInt16
            if minRgb == maxRgb {
                hue        = 0
                saturation = 0
                brightness = UInt16(maxRgb * CGFloat(UInt16.max))
            } else {
                let d: CGFloat = (r == minRgb) ? g - b : ((b == minRgb) ? r - g : b - r)
                let h: CGFloat = (r == minRgb) ? 3 : ((b == minRgb) ? 1 : 5)
                hue        = UInt16((h - d/(maxRgb - minRgb)) / 6 * CGFloat(UInt16.max))
                saturation = UInt16((maxRgb - minRgb) / maxRgb * CGFloat(UInt16.max))
                brightness = UInt16(maxRgb * CGFloat(UInt16.max))
            }
            self.init(hue: hue, saturation: saturation, brightness: brightness, kelvin: 5750)
        }
    }

    var color: Color? {
        didSet {
            NotificationCenter.default.post(name: notificationLightColorChanged, object: self)
        }
    }
    var infrared: UInt16?

    override init(network: LIFXNetworkController, address: Address, label: Label?) {
        super.init(network: network, address: address, label: label)
        network.receiver.register(address: address, type: LightMessage.statePower) { [weak self] in
            self?.statePower($0)
        }
        network.receiver.register(address: address, type: LightMessage.state) { [weak self] in
            self?.state($0)
        }
        network.receiver.register(address: address, type: LightMessage.stateInfrared) { [weak self] in
            self?.stateInfrared($0)
        }
    }

    override func getPower() {
        network.send(Packet(type: LightMessage.getPower, to: address))
    }

    override func setPower(_ power: PowerState, duration: Duration = 1024) {
        self.power = power
        network.send(Packet(type: LightMessage.setPower,
                            with: power.bytes + duration.bytes,
                            to:   address))
    }

    func getState() {
        network.send(Packet(type: LightMessage.getState, to: address))
    }

    func state(_ response: [UInt8]) {
        color = Color(hue:        UnsafePointer(Array(response[0...1]))
                          .withMemoryRebound(to: UInt16.self, capacity: 1, { $0.pointee }),
                      saturation: UnsafePointer(Array(response[2...3]))
                          .withMemoryRebound(to: UInt16.self, capacity: 1, { $0.pointee }),
                      brightness: UnsafePointer(Array(response[4...5]))
                          .withMemoryRebound(to: UInt16.self, capacity: 1, { $0.pointee }),
                      kelvin:     UnsafePointer(Array(response[6...7]))
                          .withMemoryRebound(to: UInt16.self, capacity: 1, { $0.pointee }))
        let powerValue = UnsafePointer(Array(response[10...11]))
            .withMemoryRebound(to: UInt16.self, capacity: 1, { $0.pointee })
        if let power = PowerState(rawValue: powerValue) {
            self.power = power
        }
        if let label = String(bytes: response[12...43], encoding: .utf8) {
            self.label = label
        }
    }

    func setColor(_ color: Color, duration: Duration = 1024) {
        self.color = color
        network.send(Packet(type: LightMessage.setColor,
                            with: [0] + color.bytes + duration.bytes,
                            to:   address))
    }

    func getInfrared() {
        network.send(Packet(type: LightMessage.getInfrared, to: address))
    }

    func setInfrared(level infrared: UInt16) {
        self.infrared = infrared
        network.send(Packet(type: LightMessage.setInfrared, with: [], to: address))
    }

    func stateInfrared(_ response: [UInt8]) {
        infrared = UnsafePointer(Array(response[0...1]))
            .withMemoryRebound(to: UInt16.self, capacity: 1, { $0.pointee })
    }
}

extension Label {
    var bytes: [UInt8] {
        return [UInt8](utf8)
    }
}

extension Duration {
    var bytes: [UInt8] {
        return [self[0].toU8, self[1].toU8, self[2].toU8, self[3].toU8]
    }
}
