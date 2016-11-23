//
//  LIFXModel.swift
//  LIFX Remote
//
//  Created by David Wu on 6/17/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Darwin
import Cocoa

typealias Label    = String
typealias Duration = UInt32

class LIFXModel {
    
    enum LIFXError: Error {
        case duplicateDeviceLabel
    }
    
    var error: LIFXError? = nil
    var network = LIFXNetworkController()
    var devices: [LIFXDevice] = []
    
    func getDevice(withLabel label: String) -> LIFXDevice? {
        return devices.first(where: { (device) -> Bool in
            return device.label == label
        })
    }
    
    /// Discover devices
    func scan(_ completionHandler: @escaping ([UInt8]) -> Void) {
        network.send(Packet(type: DeviceMessage.getService)) { response in
            completionHandler(response)
        }
        self.error = self.add(device: LIFXLight(network: self.network, address: 0, label: "Foo"))
        self.error = self.add(device: LIFXLight(network: self.network, address: 0, label: "Foo 2"))
    }
    
    func add(device: LIFXDevice) -> LIFXError? {
        if devices.contains(device) {
            return LIFXError.duplicateDeviceLabel
        }
        devices.append(device)
        return nil
    }
    
    func remove(device: LIFXDevice) {
        devices = devices.filter { (_device) -> Bool in
            return device != _device
        }
    }
    
    func change(device: LIFXDevice, state: LIFXDevice.PowerState) {
        if let _device = devices.first(where: { (_device) -> Bool in
            return device == _device
        }) {
            _device.power = state
        }
    }
    
    func changeAllDevices(state: LIFXDevice.PowerState) {
        for device in devices {
            device.power = state
        }
    }
}

class LIFXNetworkController {
    
    /// `Receiver` continually receives UDP packets and executes their associated completion handlers
    class Receiver {
        private var socket: Int32
        private var isReceiving = false
        /// Maps devices to their pending completion handlers
        private var tasks: [String:([UInt8]) -> Void] = [:]
        
        init(socket: Int32) {
            self.socket = socket
        }
        
        func listen() {
            isReceiving = true
            DispatchQueue.global(qos: .utility).async {
                var resLen = socklen_t(MemoryLayout<sockaddr>.size)
                while self.isReceiving {
                    var recvaddr = sockaddr_in()
                    let response = [UInt8](repeating: 0, count: 128)
                    withUnsafePointer(to: &recvaddr) {
                        let n = recvfrom(self.socket,
                                         UnsafeMutablePointer(mutating: response),
                                         response.count,
                                         0,
                                         unsafeBitCast($0, to: UnsafeMutablePointer<sockaddr>.self),
                                         &resLen)
                        assert(n >= 0)
                        
                        print("Foo")
                        guard let packet = Packet(bytes: response) else {
                            print("response:\n\t\(response)")
                            print(recvaddr)
                            return
                        }
                        
                        // Get relevant task
                        let taskId = "\(packet.header.target)\(packet.header.type.message)"
                        guard let task = self.tasks[taskId] else { return }
                        
                        // Execute the relevant task
                        DispatchQueue.main.async {
                            if let payload = packet.payload {
                                task(payload.bytes)
                            }
                        }
                        
                        self.tasks[taskId] = nil
                    }
                }
            }
        }
        
        func stopListening() {
            isReceiving = false
        }
        
        func addTask(header: Header, _ task: @escaping ([UInt8]) -> Void) {
            let correspondingMessageTypes: [UInt16:UInt16] = [
                DeviceMessage.getService.rawValue     : DeviceMessage.stateService.rawValue,
                DeviceMessage.getHostInfo.rawValue    : DeviceMessage.stateHostInfo.rawValue,
                DeviceMessage.getHostFirmware.rawValue: DeviceMessage.stateHostFirmware.rawValue,
                DeviceMessage.getWifiInfo.rawValue    : DeviceMessage.stateWifiInfo.rawValue,
                DeviceMessage.getWifiFirmware.rawValue: DeviceMessage.stateHostFirmware.rawValue,
                DeviceMessage.getPower.rawValue       : DeviceMessage.statePower.rawValue,
                DeviceMessage.getLabel.rawValue       : DeviceMessage.stateLabel.rawValue,
                DeviceMessage.getVersion.rawValue     : DeviceMessage.stateVersion.rawValue,
                DeviceMessage.getInfo.rawValue        : DeviceMessage.stateInfo.rawValue,
                DeviceMessage.getLocation.rawValue    : DeviceMessage.stateLocation.rawValue,
                DeviceMessage.getGroup.rawValue       : DeviceMessage.stateGroup.rawValue,
                DeviceMessage.echoRequest.rawValue    : DeviceMessage.echoResponse.rawValue,
                LightMessage.getState.rawValue        : LightMessage.state.rawValue,
                LightMessage.getPower.rawValue        : LightMessage.statePower.rawValue,
                LightMessage.getInfrared.rawValue     : LightMessage.stateInfrared.rawValue
            ]
            tasks["\(header.target)\(correspondingMessageTypes[header.type.message]!)"] = task
        }
        
        deinit {
            stopListening()
        }
    }
    
    enum State {
        case active
        case inactive
    }
    
    let receiver: Receiver
    var state:    State = .inactive
    var sock:     Int32
    private var operationCount = 0 {
        didSet {
            state = operationCount > 0 ? .active : .inactive
        }
    }
    
    init() {
        let _sock = socket(PF_INET, SOCK_DGRAM, 0)
        assert(_sock >= 0)
        var broadcastFlag = 1
        let setSuccess = setsockopt(_sock,
                                    SOL_SOCKET,
                                    SO_BROADCAST,
                                    &broadcastFlag,
                                    socklen_t(MemoryLayout<Int>.size))
        assert(setSuccess == 0)
        
        var addr = sockaddr_in()
        addr.sin_len         = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family      = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = INADDR_ANY
        addr.sin_port        = UInt16(56700).bigEndian
        withUnsafePointer(to: &addr) {
            let bindSuccess = bind(_sock,
                                   unsafeBitCast($0, to: UnsafePointer<sockaddr>.self),
                                   socklen_t(MemoryLayout<sockaddr>.size))
            assert(bindSuccess == 0)
        }
        
        self.sock     = _sock
        self.receiver = Receiver(socket: self.sock)
        self.receiver.listen()
    }
    
    /// Send packet and pass response to handler
    func send(_ packet: Packet, _ completionHandler: (([UInt8]) -> Void)? = nil) {
        operationCount += 1
        DispatchQueue.global(qos: .utility).async {
            print(packet)
            guard let data = Data(packet: packet) else { return }
            var broadcastAddr = sockaddr_in()
            broadcastAddr.sin_len         = UInt8(MemoryLayout<sockaddr>.size)
            broadcastAddr.sin_family      = sa_family_t(AF_INET)
            broadcastAddr.sin_addr.s_addr = INADDR_BROADCAST
            broadcastAddr.sin_port        = UInt16(56700).bigEndian
            withUnsafePointer(to: &broadcastAddr) {
                let n = sendto(self.sock,
                               (data as NSData).bytes,
                               data.count,
                               0,
                               unsafeBitCast($0, to: UnsafePointer<sockaddr>.self),
                               socklen_t(MemoryLayout<sockaddr_in>.size))
                assert(n >= 0)
            }
            
            if packet.header.res {
                self.receiver.addTask(header: packet.header) { response in
                    if let completionHandler = completionHandler {
                        completionHandler(response)
                    }
                    self.operationCount -= 1
                }
            } else {
                DispatchQueue.main.async {
                    // There usually isn't a completionHandler if no response is expected
                    if let completionHandler = completionHandler {
                        completionHandler([UInt8]())
                    }
                    self.operationCount -= 1
                }
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
    
    var network: LIFXNetworkController
    var service: Service = .udp
    var port:    UInt32 = 56700
    var address: UInt64
    var label: Label {
        didSet {
            setLabel(label)
        }
    }
    var power: PowerState = .standby {
        didSet {
            setPower(level: power)
        }
    }
    
    init(network: LIFXNetworkController, address: UInt64, label: Label) {
        self.network = network
        self.address = address
        self.label   = label
    }
    
    func getPower() {
        network.send(Packet(type: DeviceMessage.getPower, to: address)) { response in
            self.power = .enabled
        }
    }
    
    func setPower(level: PowerState, duration: Duration = 1024) {
        network.send(Packet(type: DeviceMessage.setPower,
                            with: level.bytes + duration.bytes,
                            to:   address))
    }
    
    func getLabel() {
        network.send(Packet(type: DeviceMessage.getLabel, to: address)) { response in
            guard let label = String(bytes: response, encoding: .utf8) else {
                print("getLabel error")
                return
            }
            self.label = label
        }
    }
    
    func setLabel(_ label: String) {
        network.send(Packet(type: DeviceMessage.setLabel, with: label.bytes, to: address))
    }
    
    /// Get device service and port
    func getService() {
        network.send(Packet(type: DeviceMessage.getService, to: address)) { response in
            if let service = Service(rawValue: response[0]) {
                self.service = service
            }
            self.port = UnsafePointer(Array(response[1...4])).withMemoryRebound(to: UInt32.self,
                                                                                capacity: 1,
                                                                                { $0.pointee })
        }
    }
    
    /*
    /// Get host signal, tx, rx
    func getHostInfo() -> (Float32, UInt32, UInt32) {
        
    }
    
    /// Get host firmware build, version
    func getHostFirmware() -> (UInt64, UInt32) {
        
    }
    
    /// Get Wifi subsystem signal, tx, rx
    func getWifiInfo() -> (Float32, UInt32, UInt32) {
        
    }
    
    /// Get Wifi subsystem build, version
    func getWifiFirmware() -> (UInt64, UInt32) {
        
    }
    
    /// Get device hardware vendor, product, version
    func getVersion() -> (UInt32, UInt32, UInt32) {

    }
    */
    
    /// Print device time, uptime, downtime
    func getInfo() {
        network.send(Packet(type: DeviceMessage.getInfo, to: address)) { response in
            let dtime    = UnsafePointer(Array(response[0...8])).withMemoryRebound(to: UInt64.self,
                                                                                   capacity: 1,
                                                                                   { $0.pointee })
            let uptime   = UnsafePointer(Array(response[8...16])).withMemoryRebound(to: UInt64.self,
                                                                                    capacity: 1,
                                                                                    { $0.pointee })
            let downtime = UnsafePointer(Array(response[16...24])).withMemoryRebound(to: UInt64.self,
                                                                                     capacity: 1,
                                                                                     { $0.pointee })
            print("Device time: \(dtime), uptime: \(uptime), downtime: \(downtime)")
        }
    }
    
    /*
    /// Get device location, label, updated_at
    func getLocation() -> ([UInt8], String, UInt64) {

    }
    
    /// Get group, label, updated_at
    func getGroup() -> ([UInt8], String, UInt64) {

    }
    */
    
    /// Send payload to device and print echo
    func echoRequest(payload: [UInt8]) {
        network.send(Packet(type: DeviceMessage.echoRequest, with: payload, to: address)) { response in
            print("echo:\n\t\(response)")
        }
    }
}

extension LIFXDevice: Equatable {
    static func ==(lhs: LIFXDevice, rhs: LIFXDevice) -> Bool {
        return lhs.label == rhs.label
    }
}

extension LIFXDevice: Hashable {
    var hashValue: Int {
        return label.hashValue
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
            let hue:        [UInt8] = [self.hue[0].toU8, self.hue[1].toU8]
            let saturation: [UInt8] = [self.saturation[0].toU8, self.saturation[1].toU8]
            let brightness: [UInt8] = [self.brightness[0].toU8, self.brightness[1].toU8]
            let kelvin:     [UInt8] = [self.kelvin[0].toU8, self.kelvin[1].toU8]
            return hue + saturation + brightness + kelvin
        }
    }
    
    var color: Color? = Color(hue: 21485, saturation: 65355, brightness: 30000, kelvin: 3500) {
        didSet {
            if let color = color {
                setColor(color: color)
            }
        }
    }
    
    override func getPower() {
        network.send(Packet(type: LightMessage.getPower, to: address)) { response in
            if let power = PowerState(rawValue: UnsafePointer(Array(response[0...2])).withMemoryRebound(
                               to: UInt16.self, capacity: 1, { $0.pointee })) {
                self.power = power
            }
        }
    }

    override func setPower(level: PowerState, duration: Duration = 1024) {
        network.send(Packet(type: LightMessage.setPower,
                            with: level.bytes + duration.bytes,
                            to:   address))
    }
    
    func getState() {
        network.send(Packet(type: LightMessage.getState)) { response in
            self.color =
                Color(hue:        UnsafePointer(Array(response[0...1])).withMemoryRebound(to: UInt16.self,
                                                                                          capacity: 1,
                                                                                          { $0.pointee }),
                      saturation: UnsafePointer(Array(response[2...3])).withMemoryRebound(to: UInt16.self,
                                                                                          capacity: 1,
                                                                                          { $0.pointee }),
                      brightness: UnsafePointer(Array(response[4...5])).withMemoryRebound(to: UInt16.self,
                                                                                          capacity: 1,
                                                                                          { $0.pointee }),
                      kelvin:     UnsafePointer(Array(response[6...7])).withMemoryRebound(to: UInt16.self,
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
    }
    
    func setColor(color: Color, duration: Duration = 1024) {
        network.send(Packet(type: LightMessage.setColor,
                            with: [0] + color.bytes + duration.bytes,
                            to:   address))
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
