//
//  LIFXModel.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 6/17/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Foundation

let notificationDevicesChanged = NSNotification.Name(rawValue: "net.gofake1.devicesChangedKey")

class LIFXModel: NSObject {

    @objc dynamic var devices = [LIFXDevice]() {
        didSet {
            if devices.count != oldValue.count {
                devicesCountChangeHandlers.forEach { $0(devices.count) }
            }
            NotificationCenter.default.post(name: notificationDevicesChanged, object: self)
        }
    }
    @objc dynamic var groups = [LIFXGroup]() {
        didSet {
            if groups.count != oldValue.count {
                groupsCountChangeHandlers.forEach { $0(groups.count) }
            }
        }
    }
    let network = LIFXNetworkController()
    /// Device and group visibility state in the status menu
    private(set) var itemVisibility: [AnyHashable: Bool] = [:]
    private var statusChangeHandlers: [(LIFXNetworkController.Status) -> Void] = []
    private var devicesCountChangeHandlers: [(Int) -> Void] = []
    private var groupsCountChangeHandlers: [(Int) -> Void] = []
    private static let savedStateCSVPath =
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SavedState")
            .appendingPathExtension("csv")
            .path
    static let shared: LIFXModel = {
        guard FileManager.default.fileExists(atPath: savedStateCSVPath),
            let savedState = FileManager.default.contents(atPath: savedStateCSVPath)
            else { return LIFXModel() }
        return LIFXModel(savedState: savedState)
    }()

    override init() {
        super.init()
    }

    /// Initialize with saved devices and groups
    convenience init(savedState: Data) {
        self.init()
        let savedStateCSV = CSV(String(data: savedState, encoding: .utf8))
        for line in savedStateCSV.lines {
            switch line.values[0] {
            case "device":
                add(device: LIFXLight(network: network, csvLine: line), connected: false)
            case "group":
                add(group: LIFXGroup(csvLine: line))
            case "visibility":
                guard let visibility = Bool(line.values[3]) else { fatalError() }
                switch line.values[1] {
                case "group":
                    guard let group = group(for: line.values[2]) else { fatalError() }
                    self.setVisibility(for: group, visibility)
//                case "device":
//                    guard let device = self.device(for: line.values[2]) else { fatalError() }
//                    self.setVisibility(for: device, visibility)
                default:
                    break
                }
            default:
                break
            }
        }
    }

    func onNewDevice(_ response: [UInt8], _ ipAddress: String) {
        let address: Address = UnsafePointer(Array(response[8...15]))
            .withMemoryRebound(to: Address.self, capacity: 1, { $0.pointee })

        if devices.contains(where: { device -> Bool in
            return device.address == address
        }) {
            return
        }

        // New device
        let light = LIFXLight(network: self.network, address: address, label: nil)
        light.service = LIFXDevice.Service(rawValue: response[36]) ?? .udp
        light.port = UnsafePointer(Array(response[37...40]))
            .withMemoryRebound(to: UInt32.self, capacity: 1, { $0.pointee })
        light.ipAddress = ipAddress
        light.getState()
        light.getVersion()

        self.add(device: light, connected: true)
        self.setVisibility(for: light, true)
        discoveryHandlers.forEach { $0() }
    }

    func device(at index: Int) -> LIFXDevice {
        return devices[index]
    }

    func device(for address: Address) -> LIFXDevice? {
        return devices.first { return $0.address == address }
    }

    func group(at index: Int) -> LIFXGroup {
        return groups[index]
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

//    func remove(device: LIFXDevice) {
//        guard let index = devices.value.index(of: device) else { return }
//        devices.remove(at: index)
//    }

    func remove(group: LIFXGroup) {
        guard let index = groups.index(of: group) else { return }
        groups.remove(at: index)
    }

    func changeAllDevices(power: LIFXDevice.PowerState) {
        devices.forEach { $0.setPower(power) }
    }

    func setVisibility(for item: AnyHashable, _ isVisible: Bool) {
        itemVisibility[item] = isVisible
    }
    
    func discover() {
        // Send heartbeat to known devices
        for device in devices {
            
        }
        network.send(Packet(type: DeviceMessage.getService))
    }

    func onStatusChange(_ handler: @escaping (LIFXNetworkController.Status) -> Void) {
        statusChangeHandlers.append(handler)
    }

    func onDevicesCountChange(_ handler: @escaping (Int) -> Void) {
        devicesCountChangeHandlers.append(handler)
    }

    func onGroupsCountChange(_ handler: @escaping (Int) -> Void) {
        groupsCountChangeHandlers.append(handler)
    }


    /// Write devices and groups to CSV files
    func saveState() {
        let savedStateCSV = CSV()
        savedStateCSV.append(line: CSV.Line("version", "1"))
        devices.forEach { savedStateCSV.append(lineString: $0.csvString) }
        groups.forEach { savedStateCSV.append(lineString: $0.csvString) }
        itemVisibility.forEach {
            switch $0.key {
            case let group as LIFXGroup:
                savedStateCSV.append(line: CSV.Line("visibility", "group", group.id, String($0.value)))
//            case let device as LIFXDevice:
//                savedStateCSV.append(line: CSV.Line("visibility", "device", String(device.address),
//                                                    String($0.value)))
            default: break
            }
        }
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
//        /// Devices are expected to send acknowledgement to prove they're alive
//        private var acknowledgementsExpected: [Address: Bool] = [:]
        
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

                        let recvIp = String(validatingUTF8: inet_ntoa(recvAddr.sin_addr)) ?? "couldn't parse IP"
                    #if DEBUG
                        var log = "response \(recvIp):\n"
                    #endif
                        guard let packet = Packet(bytes: res) else {
                        #if DEBUG
                            log += "\tunknown packet type\n"
                            print(log)
                        #endif
                            return
                        }
                    #if DEBUG
                        log += "\tfrom \(packet.header.target.bigEndian)\n"
                        log += "\t\(packet.header.type)\n"
                        print(log)
                    #endif
                        
                        let address = packet.header.target.bigEndian
                        let type    = packet.header.type.message
                        let payload = packet.payload?.bytes ?? [UInt8]()
                        var task: (([UInt8]) -> Void)?
                        
                        // Handle discovery response
                        if type == DeviceMessage.stateService.rawValue {
                            // This packet is from a known address
                            if let tasks = self.tasks[address] {
                                task = tasks[type]
                            // This packet is from a new address
                            } else {
                                let ipAddress = String(validatingUTF8: inet_ntoa(recvAddr.sin_addr)) ?? "Error"
                                // Include packet header to get the MAC address
                                LIFXModel.shared.onNewDevice(packet.header.bytes + payload, ipAddress)
                                return
                            }
                        // Handle all other responses
                        } else {
                            if let tasks = self.tasks[address] {
                                task = tasks[type]
                            }
                        }
                        
                        // Execute the task
                        DispatchQueue.main.async {
                            if let task = task {
                                task(payload)
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
        func register(address: Address, type: LIFXMessageType, task: @escaping ([UInt8]) -> Void) {
            if tasks[address] == nil {
                tasks[address] = [:]
            }
            tasks[address]![type.message] = task
        }

        func unregister(_ address: Address) {
            tasks[address] = nil
        }
    }

    enum Status {
        case normal
        case offline
    }
    
    let receiver:      Receiver
    var sock:          Int32
    var broadcastAddr: sockaddr_in
    var status = Status.normal

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
        receiver = Receiver(socket: sock)
        receiver.listen()
        broadcastAddr = sockaddr_in(sin_len:    UInt8(MemoryLayout<sockaddr_in>.size),
                                    sin_family: sa_family_t(AF_INET),
                                    sin_port:   UInt16(56700).bigEndian,
                                    sin_addr:   in_addr(s_addr: INADDR_BROADCAST),
                                    sin_zero:   (0, 0, 0, 0, 0, 0, 0, 0))
    }
    
    func send(_ packet: Packet) {
    #if DEBUG
        print("sent \(packet)\n")
    #endif
        let data = Data(packet: packet)
        withUnsafePointer(to: &self.broadcastAddr) {
            let n = sendto(self.sock,
                           (data as NSData).bytes,
                           data.count,
                           0,
                           unsafeBitCast($0, to: UnsafePointer<sockaddr>.self),
                           socklen_t(MemoryLayout<sockaddr_in>.size))
            if n < 0 {
                status = .offline
            #if DEBUG
                print(String(validatingUTF8: strerror(errno)) ?? "Couldn't display error")
            #endif
            } else {
                status = .normal
            }
        }
    }
    
    deinit {
        receiver.stopListening()
        close(sock)
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
