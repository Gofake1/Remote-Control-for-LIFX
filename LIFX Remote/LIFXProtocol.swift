//
//  LIFXProtocol.swift
//  LIFX Remote
//
//  Created by David Wu on 6/16/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Foundation

/// A type that describes a LIFX message
protocol Messagable {
    var message: UInt16 { get }
}

enum DeviceMessage: UInt16, Messagable {
    case getService        = 2
    case stateService      = 3
    case getHostInfo       = 12
    case stateHostInfo     = 13
    case getHostFirmware   = 14
    case stateHostFirmware = 15
    case getWifiInfo       = 16
    case stateWifiInfo     = 17
    case getWifiFirmware   = 18
    case stateWifiFirmware = 19
    case getPower          = 20
    case setPower          = 21
    case statePower        = 22
    case getLabel          = 23
    case setLabel          = 24
    case stateLabel        = 25
    case getVersion        = 32
    case stateVersion      = 33
    case getInfo           = 34
    case stateInfo         = 35
    case acknowledgement   = 45
    case getLocation       = 48
    case stateLocation     = 50
    case getGroup          = 51
    case stateGroup        = 53
    case echoRequest       = 58
    case echoResponse      = 59
    
    var message: UInt16 {
        return rawValue
    }
}

enum LightMessage: UInt16, Messagable {
    case getState      = 101
    case setColor      = 102
    case state         = 107
    case getPower      = 116
    case setPower      = 117
    case statePower    = 118
    case getInfrared   = 120
    case stateInfrared = 121
    case setInfrared   = 122
    
    var message: UInt16 {
        return rawValue
    }
}

struct Packet {
    var header: Header
    var payload: Payload?
    
    /// - parameter target: MAC address or nil (all devices)
    init(type: Messagable, with payload: [UInt8]? = nil, to target: UInt64? = nil) {
        self.header  = Header(type: type, target: target)
        self.payload = Payload(bytes: payload)
    }
    
    init?(bytes: [UInt8]) {
        guard let header = Header(bytes: Array(bytes[0...36])) else { return nil }
        self.header  = header
        self.payload = Payload(bytes: Array(bytes[36...bytes.count]))
    }
}

extension Packet: CustomStringConvertible {
    var description: String {
        var d = "header:\n\ttype: \(header.type)\n\tbytes: \(header.bytes)\n"        
        if let payload = payload {
            d += "payload:\n\tbytes: \(payload.bytes)"
        } else {
            d += "payload:\n\tnone"
        }
        return d
    }
}

struct Header {
    // Frame
    var size: UInt16 {
        switch type {
        case DeviceMessage.setLabel:
            return 68
        case DeviceMessage.setPower: fallthrough
        case LightMessage.setPower:
            return 38
        case LightMessage.setColor:
            return 49
        default:
            return 36
        }
    }
    var tagged: Bool   = false
    var source: UInt32 = 0
    
    // Frame address
    var target: UInt64 // MAC address or 0 (broadcast)
    var ack: Bool = false
    var res: Bool = false
    var sequence: UInt8 {
        return 0
    }
    
    // Protocol
    var type: Messagable
    
    /// Little-endian
    var bytes: [UInt8] {
        var flags: UInt8 = 0
        if res {
            flags = flags.setb0(1)
        }
        if ack {
            flags = flags.setb1(1)
        }
        return [
            size[0].toU8,
            size[1].toU8,
            0,
            tagged ? 0b00110100 : 0b00010100,
            source[0].toU8,
            source[1].toU8,
            source[2].toU8,
            source[3].toU8,
            target[0].toU8,
            target[1].toU8,
            target[2].toU8,
            target[3].toU8,
            target[4].toU8,
            target[5].toU8,
            target[6].toU8,
            target[7].toU8,
            0, 0, 0, 0, 0, 0,       // Frame address reserved
            flags,
            sequence,
            0, 0, 0, 0, 0, 0, 0, 0, // Protocol reserved
            type.message[0].toU8,
            type.message[1].toU8,
            0, 0                    // Protocol reserved
        ]
    }
    
    init(type: Messagable, target: UInt64?) {
        self.type = type
        self.target = target ?? 0
        
        switch type {
        case DeviceMessage.getService:
            tagged = true
            res    = true
        case DeviceMessage.getHostInfo:     fallthrough
        case DeviceMessage.getHostFirmware: fallthrough
        case DeviceMessage.getWifiInfo:     fallthrough
        case DeviceMessage.getWifiFirmware: fallthrough
        case DeviceMessage.getPower:        fallthrough
        case DeviceMessage.getLabel:        fallthrough
        case DeviceMessage.getVersion:      fallthrough
        case DeviceMessage.getInfo:         fallthrough
        case DeviceMessage.getLocation:     fallthrough
        case DeviceMessage.getGroup:        fallthrough
        case DeviceMessage.echoRequest:     fallthrough
        case LightMessage.getState:         fallthrough
        case LightMessage.getPower:         fallthrough
        case LightMessage.getInfrared:
            res = true
        default:
            break
        }
    }
    
    init?(bytes: [UInt8]) {
        let rawValue = UnsafePointer(Array(bytes[32...33])).withMemoryRebound(to: UInt16.self,
                                                                              capacity: 1,
                                                                              { $0.pointee })
        if let type: Messagable = rawValue > 100 ? DeviceMessage(rawValue: rawValue) :
                                                   LightMessage(rawValue: rawValue) {
            self.type = type
        } else {
            return nil
        }
        
        self.target = UnsafePointer(Array(bytes[8...16])).withMemoryRebound(to: UInt64.self,
                                                                            capacity: 1,
                                                                            { $0.pointee })
    }
}

struct Payload {
    var bytes: [UInt8]
    
    init?(bytes: [UInt8]?) {
        if let bytes = bytes {
            self.bytes = bytes
        } else {
            return nil
        }
    }
}
