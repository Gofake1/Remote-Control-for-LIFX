//
//  LIFXModel.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 6/17/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Foundation

let notificationDevicesChanged = NSNotification.Name(rawValue: "net.gofake1.devicesChangedKey")

enum SavedStateError: Error {
    case unknownVersionFormat
    case illegalValue
}

private func savedStateVersion(_ line: CSV.Line) throws -> Int {
    guard line.values.count == 2, line.values[0] == "version"
        else { throw SavedStateError.unknownVersionFormat }
    guard let version = Int(line.values[1]),
        version == 1 || version == 2
        else { throw SavedStateError.illegalValue }
    return version
}

class LIFXModel: NSObject {

    static let shared: LIFXModel = {
        let model = LIFXModel()
        for group in model.groups {
            group.restoreDevices(from: model)
        }
        return model
    }()
    private static let savedStateCSVPath =
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SavedState")
            .appendingPathExtension("csv")
            .path
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
    private var statusChangeHandlers: [(LIFXNetworkController.Status) -> Void] = []
    private var devicesCountChangeHandlers: [(Int) -> Void] = []
    private var groupsCountChangeHandlers: [(Int) -> Void] = []

    override init() {
        super.init()
        network.receiver.registerForUnknown(newDevice)
        if FileManager.default.fileExists(atPath: LIFXModel.savedStateCSVPath),
            let savedState = FileManager.default.contents(atPath: LIFXModel.savedStateCSVPath) {

            let savedStateCSV = CSV(String(data: savedState, encoding: .utf8))
            guard let line = savedStateCSV.lines.first else { return }
            do {
                let version = try savedStateVersion(line)
                print("Saved state version: \(version)")
                for line in savedStateCSV.lines[1...] {
                    switch line.values[0] {
                    case "device":
                        add(device: LIFXLight(network: network, csvLine: line, version: version))
                    case "group":
                        add(group: LIFXGroup(csvLine: line, version: version))
                    default:
                        break
                    }
                }
                print("Saved devices: \(devices)")
                print("Saved groups: \(groups)")
            } catch let error {
                print(error)
            }
        }
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

    func remove(device: LIFXDevice) {
        guard let index = devices.index(of: device) else { return }
        groups.forEach {
            $0.remove(device: device)
        }
        devices.remove(at: index)
    }

    func remove(group: LIFXGroup) {
        guard let index = groups.index(of: group) else { return }
        groups.remove(at: index)
    }

    func changeAllDevices(power: LIFXDevice.PowerState) {
        devices.forEach { $0.setPower(power) }
    }
    
    func discover() {
        devices.forEach {
            $0.isReachable = false
        }
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

        // New device
        let light = LIFXLight(network: network, address: address, label: nil)
        light.service = LIFXDevice.Service(rawValue: response[0]) ?? .udp
        light.port = UnsafePointer(Array(response[1...4]))
            .withMemoryRebound(to: UInt32.self, capacity: 1, { $0.pointee })
        light.ipAddress = ipAddress
        light.getState()
        light.getVersion()

        add(device: light)
    }

    func onDevicesCountChange(_ handler: @escaping (Int) -> Void) {
        devicesCountChangeHandlers.append(handler)
    }

    func onGroupsCountChange(_ handler: @escaping (Int) -> Void) {
        groupsCountChangeHandlers.append(handler)
    }

    func onStatusChange(_ handler: @escaping (LIFXNetworkController.Status) -> Void) {
        statusChangeHandlers.append(handler)
    }

    // Version 1:
    // - "device" address label
    // - "group" id name device_address...
    // Version 2:
    // - "device" address label isVisible
    // - "group" id name isVisible device_address...
    /// Write devices and groups to CSV file
    func saveState() {
        let savedStateCSV = CSV()
        savedStateCSV.append(line: CSV.Line("version", "2"))
        devices.forEach { savedStateCSV.append(lineString: $0.csvString) }
        groups.forEach { savedStateCSV.append(lineString: $0.csvString) }
        do { try savedStateCSV.write(to: LIFXModel.savedStateCSVPath) }
        catch { fatalError("Failed to write saved state") }
    }
}

class LIFXNetworkController {
    
    /// `Receiver` continually receives device state updates from the network and executes their associated 
    /// completion handlers
    class Receiver {

        private var isReceiving = false
        private var ipAddresses: [Address: String] = [:]
        private var socket: Int32
        /// Map devices to IP address handlers
        private var tasksForIpAddressChange: [Address: (String) -> Void] = [:]
        /// Map devices to their corresponding handlers
        private var tasksForKnown: [Address: [UInt16: ([UInt8]) -> Void]] = [:]
        /// Fallback handler for unknown addresses
        private var taskForUnknown: ((UInt16, Address, [UInt8], String) -> Void)?

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

                    #if DEBUG
                        let recvIp = String(validatingUTF8: inet_ntoa(recvAddr.sin_addr)) ?? "Couldn't parse IP"
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
                        let ipAddress = String(validatingUTF8: inet_ntoa(recvAddr.sin_addr)) ?? "Error"

                        // Handle response from unknown address
                        if self.tasksForKnown[address] == nil {
                            DispatchQueue.main.async {
                                self.taskForUnknown?(type, address, payload, ipAddress)
                            }
                        // Handle all other responses
                        } else if let tasks = self.tasksForKnown[address], let task = tasks[type] {
                            DispatchQueue.main.async {
                                task(payload)
                            }
                            if let ipAddressChangeTask = self.tasksForIpAddressChange[address] {
                                // Handle IP address change
                                if let cachedIpAddress = self.ipAddresses[address] {
                                    if ipAddress != cachedIpAddress {
                                        self.ipAddresses[address] = ipAddress
                                        DispatchQueue.main.async {
                                            ipAddressChangeTask(ipAddress)
                                        }
                                    }
                                // Handle no IP address set
                                } else {
                                    self.ipAddresses[address] = ipAddress
                                    DispatchQueue.main.async {
                                        ipAddressChangeTask(ipAddress)
                                    }
                                }
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
            if tasksForKnown[address] == nil {
                tasksForKnown[address] = [:]
            #if DEBUG
                print("Registered \(address)")
            #endif
            }
            tasksForKnown[address]![type.message] = task
        }

        func register(address: Address, forIpAddressChange task: @escaping (String) -> Void) {
            tasksForIpAddressChange[address] = task
        }

        func registerForUnknown(_ task: @escaping (UInt16, Address, [UInt8], String) -> Void) {
            taskForUnknown = task
        }

        func unregister(_ address: Address) {
            tasksForKnown[address] = nil
            tasksForIpAddressChange[address] = nil
        #if DEBUG
            print("Unregistered \(address)")
        #endif
        }
    }

    enum Status {
        case normal
        case offline
    }

    var broadcastAddr: sockaddr_in
    var status = Status.normal
    var sock: Int32
    let receiver: Receiver

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
        
        self.sock = sock
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
