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
    var network = LIFXNetworkController()
    var devices = MutableProperty<[LIFXDevice]>([])
    
    /// Execute given handler on newly discovered device
    func onDiscovery(_ completionHandler: @escaping () -> Void) {
        // Add device when stateService is received
        self.network.receiver.register(address: 0, type: DeviceMessage.stateService, task: { response in
            let address: Address = UnsafePointer(Array(response[8...15]))
                                       .withMemoryRebound(to: Address.self, capacity: 1, { $0.pointee })
            // Don't add duplicate device
            if self.contains(address: address) { return }
            let light = LIFXLight(network: self.network, address: address, label: nil)
            if let service = LIFXDevice.Service(rawValue: response[36]) {
                light.service = service
            }
            light.port = UnsafePointer(Array(response[37...40]))
                             .withMemoryRebound(to: UInt32.self, capacity: 1, { $0.pointee })
            print("new device found\n\(light)\n")
            light.getState()
            light.getVersion()
            self.devices.value.append(light)
            
            completionHandler()
        })
    }
    
    func discover() {
        devices.value = []
        HudController.reset()
        network.receiver.reset()
        network.send(Packet(type: DeviceMessage.getService))
    }
    
    func contains(address: Address) -> Bool {
        return devices.value.contains(where: { (device) -> Bool in
            device.address == address
        })
    }
    
    func changeAllDevices(state: LIFXDevice.PowerState) {
        for device in devices.value {
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
                    let res      = [UInt8](repeating: 0, count: 100)
                    withUnsafePointer(to: &recvAddr) {
                        let n = recvfrom(self.socket,
                                         UnsafeMutablePointer(mutating: res),
                                         res.count,
                                         0,
                                         unsafeBitCast($0, to: UnsafeMutablePointer<sockaddr>.self),
                                         &recvAddrLen)
                        assert(n >= 0, String(validatingUTF8: strerror(errno))!)

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
                        var task:     (([UInt8]) -> Void)?
                        
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
                        guard let _task = task else { return }
                        DispatchQueue.main.async {
                           _task(response)
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

        /// Remove device handlers
        func reset() {
            for (address, _) in tasks {
                if address != 0 {
                    tasks[address] = nil
                }
            }
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
            assert(n >= 0, String(validatingUTF8: strerror(errno))!)
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
