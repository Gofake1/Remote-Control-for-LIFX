//
//  LIFXModel.swift
//  LIFX Remote
//
//  Created by David Wu on 6/17/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Darwin
import Cocoa

typealias Address  = UInt64
typealias Label    = String
typealias Duration = UInt32

class LIFXModel {
    
    var network = LIFXNetworkController()
    var devices: [LIFXDevice] = []
    
    /// Execute given handler on newly discovered device
    func onDiscovery(_ completionHandler: @escaping () -> Void) {
        // Add device when stateService is received
        self.network.receiver.register(address: 0, type: DeviceMessage.stateService, task: { response in
            let address: Address = UnsafePointer(Array(response[8...15])).withMemoryRebound(to: Address.self,
                                                                                            capacity: 1,
                                                                                            { $0.pointee })
            // Don't add duplicate device
            if self.contains(address: address) { return }
            let light = LIFXLight(network: self.network, address: address, label: nil)
            if let service = LIFXDevice.Service(rawValue: response[36]) {
                light.service = service
            }
            light.port = UnsafePointer(Array(response[37...40])).withMemoryRebound(to: UInt32.self,
                                                                                   capacity: 1,
                                                                                   { $0.pointee })
            print("new device found\n\(light)\n")
            light.getState()
            light.getWifiInfo()
            light.getVersion()
            self.devices.append(light)
            
            completionHandler()
        })
    }
    
    /// Execute given handler on device update
    func onUpdate(device: LIFXDevice, _ completionHandler: @escaping () -> Void) {
        network.receiver.register(address: device.address, type: LightMessage.state, task: { response in
            if let light = device as? LIFXLight {
                light.state(response)
                completionHandler()
            }
        })
    }
    
    func discover() {
        network.send(Packet(type: DeviceMessage.getService))
    }
    
    func contains(address: Address) -> Bool {
        return devices.contains(where: { (device) -> Bool in
            device.address == address
        })
    }
    
    func remove(device: LIFXDevice) {
        devices = devices.filter { (_device) -> Bool in
            return device != _device
        }
    }
    
    func changeAllDevices(state: LIFXDevice.PowerState) {
        for device in devices {
            device.setPower(level: state)
        }
    }
}

class LIFXNetworkController {
    
    /// `Receiver` continually receives device state updates and executes their associated completion handlers
    class Receiver {
        private var socket: Int32
        private var isReceiving = false
        /// Map devices to their corresponding completion handlers
        private var tasks: [Address:[UInt16:([UInt8]) -> Void]] = [:]
        
        init(socket: Int32) {            
            var addr = sockaddr_in()
            addr.sin_len         = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family      = sa_family_t(AF_INET)
            addr.sin_addr.s_addr = INADDR_ANY
            addr.sin_port        = UInt16(56700).bigEndian
            withUnsafePointer(to: &addr) {
                let bindSuccess = bind(socket,
                                       unsafeBitCast($0, to: UnsafePointer<sockaddr>.self),
                                       socklen_t(MemoryLayout<sockaddr>.size))
                assert(bindSuccess == 0, String(validatingUTF8: strerror(errno))!)
            }

            self.socket = socket
        }
        
        func listen() {
            isReceiving = true
            DispatchQueue.global(qos: .utility).async {
                var recvAddrLen = socklen_t(MemoryLayout<sockaddr>.size)
                while self.isReceiving {
                    var recvAddr = sockaddr_in()
                    let response = [UInt8](repeating: 0, count: 128)
                    withUnsafePointer(to: &recvAddr) {
                        let n = recvfrom(self.socket,
                                         UnsafeMutablePointer(mutating: response),
                                         response.count,
                                         0,
                                         unsafeBitCast($0, to: UnsafeMutablePointer<sockaddr>.self),
                                         &recvAddrLen)
                        assert(n >= 0, String(validatingUTF8: strerror(errno))!)
                        
                        var log = "response:\n"
                        guard let packet = Packet(bytes: response) else {
                            log += "\tunknown packet type\n"
                            print(log)
                            return
                        }
                        log += "\tfrom \(packet.header.target.bigEndian)\n"
                        log += "\t\(packet.header.type)\n"
                        print(log)
                        
                        let target    = packet.header.target.bigEndian
                        let type      = packet.header.type.message
                        var _response = packet.payload?.bytes ?? [UInt8]()
                        var task: (([UInt8]) -> Void)?
                        
                        // Handle discovery response
                        if type == DeviceMessage.stateService.rawValue {
                            // This packet is from a known address
                            if let tasks = self.tasks[target] {
                                task = tasks[type]
                            // This packet is from a new address
                            } else {
                                task = self.tasks[0]![type]
                                // Handler needs the packet header to get the address
                                _response = packet.header.bytes + (packet.payload?.bytes ?? [UInt8]())
                            }
                        // Handle all other responses
                        } else {
                            if let tasks = self.tasks[target] {
                                task = tasks[type]
                            }
                        }
                        
                        // Execute the task
                        guard let _task = task else { return }
                        DispatchQueue.main.async {
                            _task(_response)
                        }
                    }
                }
            }
        }
        
        func stopListening() {
            isReceiving = false
        }
        
        /// - parameter address: packet target
        /// - parameter type: message type
        /// - parameter task: function that should operate on incoming packet
        func register(address: Address, type: Messagable, task: @escaping ([UInt8]) -> Void) {
            if tasks[address] == nil {
                tasks[address] = [:]
            }
            tasks[address]![type.message] = task
        }
        
        deinit {
            stopListening()
        }
    }
    
    let receiver:      Receiver
    var sock:          Int32
    var broadcastAddr: sockaddr_in
    
    init() {
        let sock = socket(PF_INET, SOCK_DGRAM, 0)
        assert(sock >= 0)
        
        var broadcastFlag = 1
        let setSuccess = setsockopt(sock,
                                    SOL_SOCKET,
                                    SO_BROADCAST,
                                    &broadcastFlag,
                                    socklen_t(MemoryLayout<Int>.size))
        assert(setSuccess == 0, String(validatingUTF8: strerror(errno))!)
        
        self.sock     = sock
        self.receiver = Receiver(socket: self.sock)
        self.receiver.listen()
        self.broadcastAddr = sockaddr_in(sin_len:    UInt8(MemoryLayout<sockaddr_in>.size),
                                         sin_family: sa_family_t(AF_INET),
                                         sin_port:   UInt16(56700).bigEndian,
                                         sin_addr:   in_addr(s_addr: INADDR_BROADCAST),
                                         sin_zero:   (0, 0, 0, 0, 0, 0, 0, 0))
    }
    
    func send(_ packet: Packet) {
        DispatchQueue.global(qos: .utility).async {
            print("sent \(packet)\n")
            guard let data = Data(packet: packet) else { return }
            withUnsafePointer(to: &self.broadcastAddr) {
                let n = sendto(self.sock,
                               (data as NSData).bytes,
                               data.count,
                               0,
                               unsafeBitCast($0, to: UnsafePointer<sockaddr>.self),
                               socklen_t(MemoryLayout<sockaddr_in>.size))
                assert(n >= 0, String(validatingUTF8: strerror(errno))!)
            }
        }
    }
    
    deinit {
        self.receiver.stopListening()
        let _ = close(self.sock)
    }
}

extension Data {
    init?(packet: Packet) {
        guard let payload = packet.payload else {
            self.init(bytes: packet.header.bytes)
            return
        }
        self.init(bytes: packet.header.bytes + payload.bytes)
    }
}

class LIFXDevice {
    
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
    
    struct Location {
        var location:  [UInt8]?
        var label:     String?
        var updatedAt: UInt64?
    }
    
    struct Group {
        var group:     [UInt8]?
        var label:     String?
        var updatedAt: UInt64?
    }
    
    var network: LIFXNetworkController
    var service  = Service.udp
    var port     = UInt32(56700)
    var address: Address
    var label:   Label?
    var power    = PowerState.standby
    var wifi     = WifiInfo()
    var device   = DeviceInfo()
    var runtime  = RuntimeInfo()
    var location = Location()
    var group    = Group()
    
    init(network: LIFXNetworkController, address: Address, label: Label?) {
        self.network = network
        self.address = address
        self.label   = label
        self.network.receiver.register(address: address, type: DeviceMessage.stateService, task: { response in
            self.stateService(response)
        })
        self.network.receiver.register(address: address, type: DeviceMessage.statePower, task: { response in
            self.statePower(response)
        })
        self.network.receiver.register(address: address, type: DeviceMessage.stateLabel, task: { response in
            self.stateLabel(response)
        })
        self.network.receiver.register(address: address, type: DeviceMessage.stateWifiInfo, task: { response in
            self.stateWifiInfo(response)
        })
        self.network.receiver.register(address: address, type: DeviceMessage.stateVersion, task: { response in
            self.stateVersion(response)
        })
        self.network.receiver.register(address: address, type: DeviceMessage.stateInfo, task: { response in
            self.stateInfo(response)
        })
        self.network.receiver.register(address: address, type: DeviceMessage.echoResponse, task: { response in
            self.echoResponse(response)
        })
    }
    
    func getService() {
        network.send(Packet(type: DeviceMessage.getService, to: address))
    }
    
    func stateService(_ response: [UInt8]) {
        if let service = Service(rawValue: response[0]) {
            self.service = service
        }
        self.port = UnsafePointer(Array(response[1...4])).withMemoryRebound(to: UInt32.self,
                                                                            capacity: 1,
                                                                            { $0.pointee })
    }
    
    func getPower() {
        network.send(Packet(type: DeviceMessage.getPower, to: address))
    }
    
    func setPower(level power: PowerState, duration: Duration = 1024) {
        self.power = power
        network.send(Packet(type: DeviceMessage.setPower,
                            with: power.bytes + duration.bytes,
                            to:   address))
    }
    
    func statePower(_ response: [UInt8]) {
        self.power = PowerState(rawValue: UnsafePointer(response).withMemoryRebound(to: UInt16.self,
                                                                                    capacity: 1,
                                                                                    { $0.pointee }))!
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
        self.wifi.signal = UnsafePointer(Array(response[0...3])).withMemoryRebound(to: Float32.self,
                                                                                   capacity: 1,
                                                                                   { $0.pointee })
        self.wifi.tx = UnsafePointer(Array(response[4...7])).withMemoryRebound(to: UInt32.self,
                                                                               capacity: 1,
                                                                               { $0.pointee })
        self.wifi.rx = UnsafePointer(Array(response[8...11])).withMemoryRebound(to: UInt32.self,
                                                                                capacity: 1,
                                                                                { $0.pointee })
    }
    
    /// Get Wifi subsystem build, version
    func getWifiFirmware() {
        network.send(Packet(type: DeviceMessage.getWifiFirmware, to: address))
    }
    
    func stateWifiFirmware(_ response: [UInt8]) {
        self.wifi.build = UnsafePointer(Array(response[0...7])).withMemoryRebound(to: UInt64.self,
                                                                                  capacity: 1,
                                                                                  { $0.pointee })
        self.wifi.version = UnsafePointer(Array(response[16...19])).withMemoryRebound(to: UInt32.self,
                                                                                      capacity: 1,
                                                                                      { $0.pointee })
    }
    
    /// Get device hardware vendor, product, version
    func getVersion() {
        network.send(Packet(type: DeviceMessage.getVersion, to: address))
    }
    
    func stateVersion(_ response: [UInt8]) {
        self.device.vendor = UnsafePointer(Array(response[0...3])).withMemoryRebound(to: UInt32.self,
                                                                                     capacity: 1,
                                                                                     { $0.pointee })
        self.device.product = DeviceInfo.Product(rawValue:
            UnsafePointer(Array(response[4...7])).withMemoryRebound(to: UInt32.self,
                                                                    capacity: 1,
                                                                    { $0.pointee }))
        self.device.version = UnsafePointer(Array(response[8...11])).withMemoryRebound(to: UInt32.self,
                                                                                       capacity: 1,
                                                                                       { $0.pointee })
    }
    
    /// Print device time, uptime, downtime
    func getInfo() {
        network.send(Packet(type: DeviceMessage.getInfo, to: address))
    }
    
    func stateInfo(_ response: [UInt8]) {
        runtime.time = UnsafePointer(Array(response[0...8])).withMemoryRebound(to: UInt64.self,
                                                                               capacity: 1,
                                                                               { $0.pointee })
        runtime.uptime = UnsafePointer(Array(response[8...16])).withMemoryRebound(to: UInt64.self,
                                                                                  capacity: 1,
                                                                                  { $0.pointee })
        runtime.downtime = UnsafePointer(Array(response[16...24])).withMemoryRebound(to: UInt64.self,
                                                                                     capacity: 1,
                                                                                     { $0.pointee })
    }
    
    /// Get device location, label, updated_at
    func getLocation() {
        network.send(Packet(type: DeviceMessage.getLocation, to: address))
    }
    
    func stateLocation(_ response: [UInt8]) {
        self.location.location = Array(response[0...15])
        if let label = String(bytes: response[16...47], encoding: .utf8) {
            self.location.label = label
        }
        self.location.updatedAt = UnsafePointer(Array(response[48...55])).withMemoryRebound(to: UInt64.self,
                                                                                            capacity: 1,
                                                                                            { $0.pointee })
    }
    
    /// Get group, label, updated_at
    func getGroup() {
        network.send(Packet(type: DeviceMessage.getGroup, to: address))
    }
    
    func stateGroup(_ response: [UInt8]) {
        self.group.group = Array(response[0...15])
        if let label = String(bytes: response[16...47], encoding: .utf8) {
            self.group.label = label
        }
        self.group.updatedAt = UnsafePointer(Array(response[48...55])).withMemoryRebound(to: UInt64.self,
                                                                                         capacity: 1,
                                                                                         { $0.pointee })
    }
    
    func echoRequest(payload: [UInt8]) {
        network.send(Packet(type: DeviceMessage.echoRequest, with: payload, to: address))
    }
    
    func echoResponse(_ response: [UInt8]) {
        print("echo:\n\t\(response)\n")
    }
}

extension LIFXDevice: CustomStringConvertible {
    var description: String {
        return "device:\n\tlabel: \(label)\n\taddress: \(address)"
    }
}

extension LIFXDevice: Equatable {
    static func ==(lhs: LIFXDevice, rhs: LIFXDevice) -> Bool {
        return lhs.address == rhs.address
    }
}

extension LIFXDevice: Hashable {
    var hashValue: Int {
        return address.hashValue
    }
}

class LIFXLight: LIFXDevice {
    
    struct Color {
        var hue:        UInt16
        var saturation: UInt16
        var brightness: UInt16
        var kelvin:     UInt16
        
        var brightnessAsPercentage: Int {
            return Int(Double(brightness)/Double(UInt16.max) * 100)
        }
        
        var bytes: [UInt8] {
            let hue:        [UInt8] = [self.hue[0].toU8,        self.hue[1].toU8       ]
            let saturation: [UInt8] = [self.saturation[0].toU8, self.saturation[1].toU8]
            let brightness: [UInt8] = [self.brightness[0].toU8, self.brightness[1].toU8]
            let kelvin:     [UInt8] = [self.kelvin[0].toU8,     self.kelvin[1].toU8    ]
            return hue + saturation + brightness + kelvin
        }
        
        var cgColor: CGColor {
            let h = CGFloat(hue)/CGFloat(UInt16.max) * 6
            let s = CGFloat(saturation)/CGFloat(UInt16.max)
            let v = CGFloat(brightness)/CGFloat(UInt16.max)
            let i = floor(h)
            let f = h - i
            let p = v * (1.0 - s)
            let q = v * (1.0 - s * f)
            let t = v * (1.0 - s * (1.0 - f))
            var r, g, b: CGFloat
            
            switch i {
            case 0:
                r = v
                g = t
                b = p
            case 1:
                r = q
                g = v
                b = p
            case 2:
                r = p
                g = v
                b = t
            case 3:
                r = p
                g = q
                b = v
            case 4:
                r = t
                g = p
                b = v
            default:
                r = v
                g = p
                b = q
            }
            return CGColor(red: r, green: g, blue: b, alpha: 1)
        }
    }
    
    var color: Color?
    var infrared: UInt16?
    
    override init(network: LIFXNetworkController, address: Address, label: Label?) {
        super.init(network: network, address: address, label: label)
        self.network.receiver.register(address: address, type: LightMessage.statePower, task: { response in
            self.statePower(response)
        })
        // This handler is replaced in LIFXModel.onUpdate
        self.network.receiver.register(address: address, type: LightMessage.state, task: { response in
            self.state(response)
        })
        self.network.receiver.register(address: address, type: LightMessage.stateInfrared, task: { response in
            self.stateInfrared(response)
        })
    }
    
    override func getPower() {
        network.send(Packet(type: LightMessage.getPower, to: address))
    }

    override func setPower(level power: PowerState, duration: Duration = 1024) {
        self.power = power
        network.send(Packet(type: LightMessage.setPower,
                            with: power.bytes + duration.bytes,
                            to:   address))
    }
    
    override func statePower(_ response: [UInt8]) {
        self.power = PowerState(rawValue: UnsafePointer(response).withMemoryRebound(to: UInt16.self,
                                                                                    capacity: 1,
                                                                                    { $0.pointee }))!
    }
    
    func getState() {
        network.send(Packet(type: LightMessage.getState, to: address))
    }
    
    func state(_ response: [UInt8]) {
        self.color =
            Color(hue: UnsafePointer(Array(response[0...1])).withMemoryRebound(to: UInt16.self,
                                                                               capacity: 1,
                                                                               { $0.pointee }),
                  saturation: UnsafePointer(Array(response[2...3])).withMemoryRebound(to: UInt16.self,
                                                                                      capacity: 1,
                                                                                      { $0.pointee }),
                  brightness: UnsafePointer(Array(response[4...5])).withMemoryRebound(to: UInt16.self,
                                                                                      capacity: 1,
                                                                                      { $0.pointee }),
                  kelvin: UnsafePointer(Array(response[6...7])).withMemoryRebound(to: UInt16.self,
                                                                                  capacity: 1,
                                                                                  { $0.pointee }))
        if let power =
            PowerState(rawValue: UnsafePointer(Array(response[10...11])).withMemoryRebound(to: UInt16.self,
                                                                                           capacity: 1,
                                                                                           { $0.pointee })) {
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
        self.infrared = UnsafePointer(Array(response[0...1])).withMemoryRebound(to: UInt16.self,
                                                                                capacity: 1,
                                                                                { $0.pointee })
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
