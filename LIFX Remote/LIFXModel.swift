//
//  LIFXModel.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 6/17/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Darwin
import Foundation
import ReactiveSwift

class LIFXModel {

    private(set) var devices = MutableProperty<[LIFXDevice]>([])
    private(set) var groups  = MutableProperty<[LIFXGroup]>([])
    /// Device connection state determined by `stateService` or `acknowledgement` messages
    //private(set) var deviceConnectedState: [LIFXDevice:Bool] = [:]
    /// Device and group visibility state in the status menu
    //private(set) var itemVisibility: [AnyHashable:Bool] = [:]
    private(set) var network = LIFXNetworkController()
    private var discoveryHandlers: [() -> Void] = []
    static private var savedStateCSVPath: String = {
        let path = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SavedState").appendingPathExtension("csv").path
        return path
    }()
    static var shared: LIFXModel = {
        guard
            FileManager.default.fileExists(atPath: savedStateCSVPath),
            let savedState = FileManager.default.contents(atPath: savedStateCSVPath)
        else {
            return LIFXModel()
        }
        return LIFXModel(savedState: savedState)
    }()

    init() {
        // Called for unregistered addresses when stateService is received
        self.network.receiver.register(address: 0, type: DeviceMessage.stateService) { response in
            let address: Address = UnsafePointer(Array(response[8...15]))
                .withMemoryRebound(to: Address.self, capacity: 1, { $0.pointee })

            // Sanity check, don't add duplicate device
            if self.contains(address: address) { return }

            // New device
            let light = LIFXLight(network: self.network, address: address, label: nil)
            light.service = LIFXDevice.Service(rawValue: response[36]) ?? .udp
            light.port = UnsafePointer(Array(response[37...40]))
                .withMemoryRebound(to: UInt32.self, capacity: 1, { $0.pointee })
            light.getState()
            light.getVersion()

            self.add(device: light, connected: true)
            //self.setVisibility(for: light, true)
            self.discoveryHandlers.forEach { $0() }
        }
    }

    /// Initialize with saved devices and groups
    convenience init(savedState: Data) {
        self.init()
        let savedStateCSV = CSV(String(data: savedState, encoding: .utf8))
        for line in savedStateCSV.lines {
            switch line.values[0] {
            case "device":
                self.add(device: LIFXLight(network: self.network, csvLine: line), connected: true)
            case "group":
                self.add(group: LIFXGroup(csvLine: line))
//            case "visibility":
//                guard let visibility = Bool($0.values[3]) else { fatalError() }
//                switch $0.values[1] {
//                case "device":
//                    guard
//                        let address = Address($0.values[2]),
//                        let device = self.device(for: address)
//                    else { fatalError() }
//                    self.setVisibility(for: device, visibility)
//                case "group":
//                    guard
//                        let id = String($0.values[2]),
//                        let group = self.group(for: id)
//                    else { fatalError() }
//                    self.setVisibility(for: group, visibility)
//                default: break
//                }
            default: break
            }
        }
    }

    func device(at index: Int) -> LIFXDevice {
        return devices.value[index]
    }

    func device(for address: Address) -> LIFXDevice? {
        return devices.value.first { return $0.address == address }
    }

    func group(at index: Int) -> LIFXGroup {
        return groups.value[index]
    }

    func group(for id: String) -> LIFXGroup? {
        return groups.value.first { return $0.id == id }
    }

    func item(at index: Int) -> Either<LIFXGroup, LIFXDevice> {
        if index < groups.value.count {
            return Either.left(group(at: index))
        }
        return Either.right(device(at: index - groups.value.count))
    }

    func add(device: LIFXDevice, connected: Bool) {
        devices.value.append(device)
        //deviceConnectedState[device] = connected
    }

    func add(group: LIFXGroup) {
        groups.value.append(group)
    }

    func removeGroup(at index: Int) {
        //let group = groups.value[index]
        groups.value.remove(at: index)
        //itemVisibility[group] = nil
    }

//    func setVisibility(for item: AnyHashable, _ isVisible: Bool) {
//        itemVisibility[item] = isVisible
//    }

//    func setConnectedState(for device: LIFXDevice, _ isConnected: Bool) {
//        deviceConnectedState[device] = isConnected
//    }

    /// Execute given handler on newly discovered device
    func onDiscovery(_ completionHandler: @escaping () -> Void) {
        discoveryHandlers.append(completionHandler)
    }
    
    func discover() {
        devices.value        = []
        //deviceConnectedState = [:]
        //itemVisibility       = [:]
        HudController.reset()
        network.receiver.reset()
        network.send(Packet(type: DeviceMessage.getService))
    }
    
    func contains(address: Address) -> Bool {
        return devices.value.contains { $0.address == address }
    }

//    func connectedTo(address: Address) -> Bool {
//        return deviceConnectedState.contains { return $0.key.address == address }
//    }

    func changeAllDevices(power: LIFXDevice.PowerState) {
        devices.value.forEach { $0.setPower(power) }
    }

    /// Reinitialize groups with their devices, after LIFXModel has initialized
//    func restoreGroups() {
//        groups.value.forEach { $0.restore() }
//    }

    /// Write devices and groups to CSV files
    func saveState() {
        let savedStateCSV = CSV()
        savedStateCSV.append(line: CSV.Line("version", "1"))
        devices.value.forEach { savedStateCSV.append(lineString: $0.csvString) }
        groups.value.forEach { savedStateCSV.append(lineString: $0.csvString) }
//        itemVisibility.forEach {
//            switch $0.key {
//            case let group as LIFXGroup:
//                savedStateCSV.append(line: CSV.Line("visibility", "group", group.id, String($0.value)))
//            case let device as LIFXDevice:
//                savedStateCSV.append(line: CSV.Line("visibility", "device", String(device.address),
//                                                    String($0.value)))
//            default: break
//            }
//        }
        do { try savedStateCSV.write(to: LIFXModel.savedStateCSVPath) }
        catch { fatalError() }
    }
}

class LIFXNetworkController {
    
    /// `Receiver` continually receives device state updates from the network and executes their associated 
    /// completion handlers
    class Receiver {

        private var socket: Int32
        private var isReceiving = false
        /// Map devices to their corresponding completion handlers
        private var tasks: [Address: [UInt16: ([UInt8]) -> Void]] = [:]
        /// Devices are expected to send acknowledgement to prove they're alive
        //private var acknowledgementsExpected: [Address: Bool] = [:]
        
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
                assert(bindSuccess == 0, String(validatingUTF8: strerror(errno)) ?? "Couldn't display error")
            }

            self.socket = socket
        }
        
        func listen() {
            isReceiving = true
            DispatchQueue.global(qos: .utility).async {
                var recvAddrLen = socklen_t(MemoryLayout<sockaddr>.size)
                while self.isReceiving {
                    var recvAddr = sockaddr_in()
                    let res      = [UInt8](repeating: 0, count: 100)
                    withUnsafePointer(to: &recvAddr) {
                        let n = recvfrom(self.socket,
                                         UnsafeMutablePointer(mutating: res),
                                         res.count,
                                         0,
                                         unsafeBitCast($0, to: UnsafeMutablePointer<sockaddr>.self),
                                         &recvAddrLen)
                        assert(n >= 0, String(validatingUTF8: strerror(errno)) ?? "Couldn't display error")

                        var log = "response:\n"
                        guard let packet = Packet(bytes: res) else {
                            log += "\tunknown packet type\n"
                            print(log)
                            return
                        }
                        log += "\tfrom \(packet.header.target.bigEndian)\n"
                        log += "\t\(packet.header.type)\n"
                        print(log)
                        
                        let target    = packet.header.target.bigEndian
                        let type      = packet.header.type.message
                        var response  = packet.payload?.bytes ?? [UInt8]()
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
                                response = packet.header.bytes + response
                            }
                        // Handle all other responses
                        } else {
                            if let tasks = self.tasks[target] {
                                task = tasks[type]
                            }
                        }
                        
                        // Execute the task
                        DispatchQueue.main.async {
                            if let task = task {
                                task(response)
                            }
                        }
                    }
                }
            }
        }
        
        func stopListening() {
            isReceiving = false
        }

        /// Add completion handler for given device address and message type
        /// - parameter address: packet target
        /// - parameter type: message type
        /// - parameter task: function that should operate on incoming packet
        func register(address: Address, type: Messagable, task: @escaping ([UInt8]) -> Void) {
            if tasks[address] == nil {
                tasks[address] = [:]
            }
            tasks[address]![type.message] = task
        }

        /// Remove device handlers
        func reset() {
            for (address, _) in tasks {
                // Keep discovery handlers
                if address != 0 {
                    tasks[address] = nil
                }
            }
        }
    }

    enum Error {
        case none
        case offline
    }
    
    let receiver:      Receiver
    var sock:          Int32
    var broadcastAddr: sockaddr_in
    var error =        MutableProperty<Error>(.none)

    init() {
        let sock = socket(PF_INET, SOCK_DGRAM, 0)
        assert(sock >= 0)
        
        var broadcastFlag = 1
        let setSuccess = setsockopt(sock,
                                    SOL_SOCKET,
                                    SO_BROADCAST,
                                    &broadcastFlag,
                                    socklen_t(MemoryLayout<Int>.size))
        assert(setSuccess == 0, String(validatingUTF8: strerror(errno)) ?? "Couldn't display error")
        
        self.sock     = sock
        self.receiver = Receiver(socket: sock)
        self.receiver.listen()
        self.broadcastAddr = sockaddr_in(sin_len:    UInt8(MemoryLayout<sockaddr_in>.size),
                                         sin_family: sa_family_t(AF_INET),
                                         sin_port:   UInt16(56700).bigEndian,
                                         sin_addr:   in_addr(s_addr: INADDR_BROADCAST),
                                         sin_zero:   (0, 0, 0, 0, 0, 0, 0, 0))
    }
    
    func send(_ packet: Packet) {
        print("sent \(packet)\n")
        let data = Data(packet: packet)
        withUnsafePointer(to: &self.broadcastAddr) {
            let n = sendto(self.sock,
                           (data as NSData).bytes,
                           data.count,
                           0,
                           unsafeBitCast($0, to: UnsafePointer<sockaddr>.self),
                           socklen_t(MemoryLayout<sockaddr_in>.size))
            if n < 0 {
                error.value = .offline
                print(String(validatingUTF8: strerror(errno)) ?? "Couldn't display error")
            } else {
                error.value = .none
            }
        }
    }
    
    deinit {
        self.receiver.stopListening()
        close(self.sock)
    }
}

extension Data {
    init(packet: Packet) {
        guard let payload = packet.payload else {
            self.init(bytes: packet.header.bytes)
            return
        }
        self.init(bytes: packet.header.bytes + payload.bytes)
    }
}
