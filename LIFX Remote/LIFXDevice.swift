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

class LIFXDevice: NSObject, HudRepresentable, StatusMenuItemRepresentable {
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
            case original1000       = 1
            case color650           = 3
            case white800LV         = 10
            case white800HV         = 11
            case white900BR30LV     = 18
            case color1000BR30      = 20
            case color1000          = 22
            case lifxA19_27         = 27
            case lifxBR30_28        = 28
            case lifxPlusA19_29     = 29
            case lifxPlusBR30_30    = 30
            case lifxZ              = 31
            case lifxZ2             = 32
            case lifxDownlight_36   = 36
            case lifxDownlight_37   = 37
            case lifxA19_43         = 43
            case lifxBR30_44        = 44
            case lifxPlusA19_45     = 45
            case lifxPlusBR30_46    = 46
            case lifxMini           = 49
            case lifxMiniWhite      = 50
            case lifxMiniDayAndDusk = 51
            case lifxGU10           = 52

            var description: String {
                switch self {
                case .original1000:         return "Original 1000"
                case .color650:             return "Color 650"
                case .white800LV:           return "White 800 LV"
                case .white800HV:           return "White 800 HV"
                case .white900BR30LV:       return "White 900 BR30 LV"
                case .color1000BR30:        return "Color 1000 BR30"
                case .color1000:            return "Color 1000"
                case .lifxA19_27:           return "LIFX A19"
                case .lifxBR30_28:          return "LIFX BR30"
                case .lifxPlusA19_29:       return "LIFX+ A19"
                case .lifxPlusBR30_30:      return "LIFX+ BR30"
                case .lifxZ:                return "LIFX Z"
                case .lifxZ2:               return "LIFX Z 2"
                case .lifxDownlight_36:     return "LIFX Downlight"
                case .lifxDownlight_37:     return "LIFX Downlight"
                case .lifxA19_43:           return "LIFX A19"
                case .lifxBR30_44:          return "LIFX BR30"
                case .lifxPlusA19_45:       return "LIFX+ A19"
                case .lifxPlusBR30_46:      return "LIFX+ BR30"
                case .lifxMini:             return "LIFX Mini"
                case .lifxMiniWhite:        return "LIFX Mini White"
                case .lifxMiniDayAndDusk:   return "LIFX Mini Day and Dusk"
                case .lifxGU10:             return "LIFX GU10"
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

    let network: LIFXNetworkController
    var hudController = HudController()
    var hudTitle: String {
        return label
    }
    var statusMenuItem = NSMenuItem()
    var service = Service.udp
    var port    = UInt32(56700)
    @objc dynamic var ipAddress = "Unknown"
    /// Responds to getService
    @objc dynamic var isReachable = false
    /// Visibility in status menu
    @objc dynamic var isVisible: Bool
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

    init(network: LIFXNetworkController, address: Address, label: Label?, isVisible: Bool = true) {
        self.network   = network
        self.address   = address
        self.label     = label ?? "Unknown"
        self.isVisible = isVisible
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
        network.receiver.register(address: address, forIpAddressChange: { [weak self] in
            self?.ipAddress = $0
        })
    }

    convenience init?(network: LIFXNetworkController, csvLine: CSV.Line, version: Int) {
        guard let address = UInt64(csvLine.values[1]) else { fatalError() }
        let label = csvLine.values[2]
        switch version {
        case 1:
            self.init(network: network, address: address, label: label)
        case 2: fallthrough
        case 3:
            let isVisible = csvLine.values[3] == "visible"
            self.init(network: network, address: address, label: label, isVisible: isVisible)
        default:
            return nil
        }
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
        statusMenuItem.representedObject = menuItemViewController
        statusMenuItem.view = menuItemViewController.view
    }

    func getService() {
        network.send(Packet(type: DeviceMessage.getService, to: address))
    }

    func stateService(_ res: [UInt8]) {
        service = Service(rawValue: res[0]) ?? .udp
        port = UnsafePointer(Array(res[1...4])).withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }
        DispatchQueue.main.async { self.isReachable = true }
    }

    func getPower() {
        network.send(Packet(type: DeviceMessage.getPower, to: address))
    }

    func setPower(_ power: PowerState, duration: Duration = 1024) {
        self.power = power
        network.send(Packet(type: DeviceMessage.setPower, with: power.bytes+duration.bytes, to: address))
    }

    func statePower(_ response: [UInt8]) {
        let value = UnsafePointer(response).withMemoryRebound(to: UInt16.self, capacity: 1, { $0.pointee })
        power = PowerState(rawValue: value) ?? .standby
    }

    func getLabel() {
        network.send(Packet(type: DeviceMessage.getLabel, to: address))
    }

    func setLabel(_ label: Label) {
        self.label = label
        network.send(Packet(type: DeviceMessage.setLabel, with: label.bytes, to: address))
    }

    func stateLabel(_ response: [UInt8]) {
        label = String(bytes: response[0...31], encoding: .utf8) ?? "Unknown"
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

    func stateWifiInfo(_ res: [UInt8]) {
        let a = Array(res[0...3]), b = Array(res[4...7]), c = Array(res[8...11])
        wifiInfo.signal = UnsafePointer(a).withMemoryRebound(to: Float32.self, capacity: 1) { $0.pointee }
        wifiInfo.tx     = UnsafePointer(b).withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }
        wifiInfo.rx     = UnsafePointer(c).withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }
    }

    /// Get Wifi subsystem build, version
    func getWifiFirmware() {
        network.send(Packet(type: DeviceMessage.getWifiFirmware, to: address))
    }

    func stateWifiFirmware(_ res: [UInt8]) {
        let a = Array(res[0...7]), b = Array(res[16...19])
        wifiInfo.build   = UnsafePointer(a).withMemoryRebound(to: UInt64.self, capacity: 1) { $0.pointee }
        wifiInfo.version = UnsafePointer(b).withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }
    }

    /// Get device hardware vendor, product, version
    func getVersion() {
        network.send(Packet(type: DeviceMessage.getVersion, to: address))
    }

    func stateVersion(_ res: [UInt8]) {
        let a = Array(res[0...3]), b = Array(res[4...7]), c = Array(res[8...11])
        let productRaw = UnsafePointer(b).withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }
        deviceInfo.vendor  = UnsafePointer(a).withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }
        deviceInfo.product = DeviceInfo.Product(rawValue: productRaw)
        deviceInfo.version = UnsafePointer(c).withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }
    }

    /// Print device time, uptime, downtime
    func getInfo() {
        network.send(Packet(type: DeviceMessage.getInfo, to: address))
    }

    func stateInfo(_ res: [UInt8]) {
        let a = Array(res[0...7]), b = Array(res[8...15]), c = Array(res[16...23])
        runtimeInfo.time     = UnsafePointer(a).withMemoryRebound(to: UInt64.self, capacity: 1) { $0.pointee }
        runtimeInfo.uptime   = UnsafePointer(b).withMemoryRebound(to: UInt64.self, capacity: 1) { $0.pointee }
        runtimeInfo.downtime = UnsafePointer(c).withMemoryRebound(to: UInt64.self, capacity: 1) { $0.pointee }
    }

    /// Get device location, label, updated_at
    func getLocation() {
        network.send(Packet(type: DeviceMessage.getLocation, to: address))
    }

    func stateLocation(_ res: [UInt8]) {
        let a = Array(res[0...15]), b = Array(res[48...55])
        locationInfo.location = a
        locationInfo.label = String(bytes: res[16...47], encoding: .utf8) ?? "Unknown"
        locationInfo.updatedAt = UnsafePointer(b).withMemoryRebound(to: UInt64.self, capacity: 1) { $0.pointee }
    }

    /// Get group, label, updated_at
    func getGroup() {
        network.send(Packet(type: DeviceMessage.getGroup, to: address))
    }

    func stateGroup(_ res: [UInt8]) {
        let a = Array(res[0...15]), b = Array(res[48...55])
        groupInfo.group = a
        groupInfo.label = String(bytes: res[16...47], encoding: .utf8) ?? "Unknown"
        groupInfo.updatedAt = UnsafePointer(b).withMemoryRebound(to: UInt64.self, capacity: 1) { $0.pointee }
    }

    func echoRequest(payload: [UInt8]) {
        network.send(Packet(type: DeviceMessage.echoRequest, with: payload, to: address))
    }

    func echoResponse(_ response: [UInt8]) {
        print("echo:\n\t\(response)\n")
    }

    func willBeRemoved() {
        network.receiver.unregister(address)
        hudController.close()
        statusMenuItem.menu?.removeItem(statusMenuItem)
    }
}

extension LIFXDevice: CSVEncodable {
    var csvLine: CSV.Line? {
        return CSV.Line("device", String(address), label, isVisible ? "visible" : "hidden")
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
            return [hue[0].toU8, hue[1].toU8, saturation[0].toU8, saturation[1].toU8, brightness[0].toU8,
                    brightness[1].toU8, kelvin[0].toU8, kelvin[1].toU8]
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

    override init(network: LIFXNetworkController, address: Address, label: Label?, isVisible: Bool = true) {
        super.init(network: network, address: address, label: label, isVisible: isVisible)
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
        network.send(Packet(type: LightMessage.setPower, with: power.bytes+duration.bytes, to: address))
    }

    func getState() {
        network.send(Packet(type: LightMessage.getState, to: address))
    }

    func state(_ res: [UInt8]) {
        let a = Array(res[0...1]), b = Array(res[2...3]), c = Array(res[4...5]), d = Array(res[6...7]),
            e = Array(res[10...11])
        let hue         = UnsafePointer(a).withMemoryRebound(to: UInt16.self, capacity: 1) { $0.pointee }
        let saturation  = UnsafePointer(b).withMemoryRebound(to: UInt16.self, capacity: 1) { $0.pointee }
        let brightness  = UnsafePointer(c).withMemoryRebound(to: UInt16.self, capacity: 1) { $0.pointee }
        let kelvin      = UnsafePointer(d).withMemoryRebound(to: UInt16.self, capacity: 1) { $0.pointee }
        let powerRaw    = UnsafePointer(e).withMemoryRebound(to: UInt16.self, capacity: 1) { $0.pointee }
        color = Color(hue: hue, saturation: saturation, brightness: brightness, kelvin: kelvin)
        power = PowerState(rawValue: powerRaw) ?? .standby
        label = String(bytes: res[12...43], encoding: .utf8) ?? "Unknown"
    }

    func setColor(_ color: Color, duration: Duration = 1024) {
        self.color = color
        network.send(Packet(type: LightMessage.setColor, with: [0]+color.bytes+duration.bytes, to: address))
    }

    func getInfrared() {
        network.send(Packet(type: LightMessage.getInfrared, to: address))
    }

    func setInfrared(level infrared: UInt16) {
        self.infrared = infrared
        network.send(Packet(type: LightMessage.setInfrared, with: [], to: address))
    }

    func stateInfrared(_ response: [UInt8]) {
        let a = Array(response[0...1])
        infrared = UnsafePointer(a).withMemoryRebound(to: UInt16.self, capacity: 1) { $0.pointee }
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
