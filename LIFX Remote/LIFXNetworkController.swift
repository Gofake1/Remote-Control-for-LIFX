//
//  LIFXNetworkController.swift
//  Remote Control for LIFX
//
//  Created by David on 11/16/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Foundation

protocol LIFXNetworkControllerDelegate: class {
    func networkStatusChanged(_ newStatus: LIFXNetworkController.Status)
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
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    let bindSuccess = bind(socket, $0, socklen_t(MemoryLayout<sockaddr>.size))
                    assert(bindSuccess == 0, String(validatingUTF8: strerror(errno)) ?? "")
                }
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
                    withUnsafeMutablePointer(to: &recvAddr) {
                        $0.withMemoryRebound(to: sockaddr.self, capacity: 1, {
                            let n = recvfrom(self.socket,
                                             UnsafeMutablePointer(mutating: res),
                                             res.count,
                                             0,
                                             $0,
                                             &recvAddrLen)
                            assert(n >= 0, String(validatingUTF8: strerror(errno)) ?? "")
                        })
                        
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
                            log += "\tfrom \(packet.header.target.bigEndian)\n\t\(packet.header.type)\n"
                            print(log)
                        #endif
                        
                        let address = packet.header.target.bigEndian
                        let type    = packet.header.type.message
                        let payload = packet.payload?.bytes ?? [UInt8]()
                        let ipAddress = String(validatingUTF8: inet_ntoa(recvAddr.sin_addr)) ?? "Error"
                        
                        // Handle response from unknown address
                        if self.tasksForKnown[address] == nil {
                            DispatchQueue.main.async { self.taskForUnknown?(type, address, payload, ipAddress) }
                        // Handle all other responses
                        } else if let tasks = self.tasksForKnown[address], let task = tasks[type] {
                            DispatchQueue.main.async { task(payload) }
                            if let ipAddressChangeTask = self.tasksForIpAddressChange[address] {
                                // Handle IP address change
                                if let cachedIpAddress = self.ipAddresses[address] {
                                    if ipAddress != cachedIpAddress {
                                        self.ipAddresses[address] = ipAddress
                                        DispatchQueue.main.async { ipAddressChangeTask(ipAddress) }
                                    }
                                // Handle no IP address set
                                } else {
                                    self.ipAddresses[address] = ipAddress
                                    DispatchQueue.main.async { ipAddressChangeTask(ipAddress) }
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
        case error
    }
    
    var broadcastAddr: sockaddr_in
    var sock: Int32
    var status = Status.normal {
        didSet {
            if status != oldValue {
                delegate?.networkStatusChanged(status)
            }
        }
    }
    weak var delegate: LIFXNetworkControllerDelegate?
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
        assert(setSuccess == 0, String(validatingUTF8: strerror(errno)) ?? "")
        
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
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let _self = self else { return }
            #if DEBUG
                print("sent \(packet)\n")
            #endif
            let data = Data(packet: packet)
            withUnsafePointer(to: &_self.broadcastAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    let n = sendto(_self.sock,
                                   (data as NSData).bytes,
                                   data.count,
                                   0,
                                   $0,
                                   socklen_t(MemoryLayout<sockaddr_in>.size))
                    if n < 0 {
                        _self.status = .error
                        #if DEBUG
                            print(String(validatingUTF8: strerror(errno)) ?? "")
                        #endif
                    } else {
                        _self.status = .normal
                    }
                }
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
