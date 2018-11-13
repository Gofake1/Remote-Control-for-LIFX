//
//  Networking.swift
//  Remote Control for LIFX
//
//  Created by David on 11/16/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Foundation

protocol Sendable {
    var data: Data { get }
//    var timeout
}

protocol Receivable {
    static func received(_ buffer: [UInt8], _ ipAddress: String)
}

final class Networking {
    private static var broadcast: sockaddr = {
        var sin = sockaddr_in(sin_len: UInt8(MemoryLayout<sockaddr_in>.size), sin_family: sa_family_t(AF_INET),
                              sin_port: UInt16(56700).bigEndian, sin_addr: in_addr(s_addr: INADDR_BROADCAST),
                              sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        return withUnsafePointer(to: &sin) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0.pointee }}
    }()
    private static let queue = DispatchQueue(label: "net.gofake1.LIFX-Remote.Networking-listen")
    private static let socket: Int32 = {
        let socket = Darwin.socket(PF_INET, SOCK_DGRAM, 0)
        assert(socket >= 0, errno.strerror)
        var flag = 1
        let setopt_ret = setsockopt(socket, SOL_SOCKET, SO_BROADCAST, &flag, socklen_t(MemoryLayout<Int>.size))
        assert(setopt_ret == 0, errno.strerror)
        var sin = sockaddr_in(sin_len: UInt8(MemoryLayout<sockaddr_in>.size), sin_family: sa_family_t(AF_INET),
                              sin_port: UInt16(56700).bigEndian, sin_addr: in_addr(s_addr: INADDR_ANY),
                              sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        let _s = withUnsafePointer(to: &sin) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }}
        let bind_ret = bind(socket, _s, socklen_t(MemoryLayout<sockaddr>.size))
        assert(bind_ret == 0, errno.strerror)
        return socket
    }()
    
    static func listen(for receivable: Receivable.Type) {
        var sin = sockaddr_in()
        var slen = socklen_t(MemoryLayout<sockaddr>.size)
        var buffer = [UInt8](repeating: 0, count: 128)
        
        func receive() {
            let _s = withUnsafeMutablePointer(to: &sin) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }}
            let n = recvfrom(socket, &buffer, buffer.count, 0, _s, &slen)
            assert(n >= 0, errno.strerror)
            sin = _s.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
            let ipAddress = String(validatingUTF8: inet_ntoa(sin.sin_addr))!
            receivable.received(buffer, ipAddress)
            buffer.removeAll(keepingCapacity: true)
        }
        
        queue.async { while true { receive() }}
    }
    
    static func send(_ sendable: Sendable) {
        let n = sendto(socket, (sendable.data as NSData).bytes, sendable.data.count, 0, &broadcast,
                       socklen_t(MemoryLayout<sockaddr_in>.size))
        assert(n >= 0, errno.strerror)
    }
}

extension LIFXPacket: Sendable {
    var data: Data {
        guard let payload = payload else { return Data(bytes: header.bytes) }
        return Data(bytes: header.bytes + payload.bytes)
    }
}

extension LIFXPacket: Receivable {
    static func received(_ buffer: [UInt8], _ ipAddress: String) {
        Logging.log("Received \(buffer)")
        guard let packet = LIFXPacket(bytes: buffer, originIpAddress: ipAddress) else { return }
        Logging.log("\(packet)")
        Router.route(packet)
    }
}

protocol LIFXPacketRoutable {
    var routeAddress: Address { get }
    func received(_ packet: LIFXPacket)
}

extension LIFXPacket {
    final class Router {
        private static var routes = [Address: LIFXPacketRoutable]()
        private static let queue = DispatchQueue(label: "net.gofake1.LIFX-Remote.LIFXPacket.Router")
        
        static func route(_ packet: LIFXPacket) {
            queue.async {
                if let route = routes[packet.header.target] {
                    route.received(packet)
                } else {
                    do { try packet.routeNotFound() } catch { Logging.log(error) }
                }
            }
        }
        
        static func register(_ route: LIFXPacketRoutable) {
            queue.async { routes[route.routeAddress] = route }
        }
        
        static func unregister(_ route: LIFXPacketRoutable) {
            queue.async { routes[route.routeAddress] = nil }
        }
    }
}

extension LIFXDevice: LIFXPacketRoutable {
    var routeAddress: Address {
        return address
    }
    
    func received(_ packet: LIFXPacket) {
        
    }
}
