//
//  LIFXProtocol.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 6/16/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

/// A type that describes a LIFX message
protocol LIFXMessageType {
    var message: UInt16 { get }
}

enum DeviceMessage: UInt16, LIFXMessageType {
    case getService         = 2
    case stateService       = 3
    case getHostInfo        = 12
    case stateHostInfo      = 13
    case getHostFirmware    = 14
    case stateHostFirmware  = 15
    case getWifiInfo        = 16
    case stateWifiInfo      = 17
    case getWifiFirmware    = 18
    case stateWifiFirmware  = 19
    case getPower           = 20
    case setPower           = 21
    case statePower         = 22
    case getLabel           = 23
    case setLabel           = 24
    case stateLabel         = 25
    case getVersion         = 32
    case stateVersion       = 33
    case getInfo            = 34
    case stateInfo          = 35
    case acknowledgement    = 45
    case getLocation        = 48
    case stateLocation      = 50
    case getGroup           = 51
    case stateGroup         = 53
    case echoRequest        = 58
    case echoResponse       = 59
    
    var message: UInt16 {
        return rawValue
    }
}

enum LightMessage: UInt16, LIFXMessageType {
    case getState       = 101
    case setColor       = 102
    case state          = 107
    case getPower       = 116
    case setPower       = 117
    case statePower     = 118
    case getInfrared    = 120
    case stateInfrared  = 121
    case setInfrared    = 122
    
    var message: UInt16 {
        return rawValue
    }
}

struct Packet {
    var header: Header
    var payload: Payload?
    
    /// - parameter target: MAC address or nil (all devices)
    init(type: LIFXMessageType, with payload: [UInt8]? = nil, to target: Address? = nil) {
        header = Header(type: type, target: target)
        self.payload = Payload(bytes: payload)
    }
    
    init?(bytes: [UInt8]) {
        guard let header = Header(bytes: Array(bytes[0...35])) else { return nil }
        self.header = header
        payload = Payload(bytes: Array(bytes[36..<Int(header.size)]))
    }
}

extension Packet: CustomStringConvertible {
    var description: String {
        return "\(header.type) packet to \(header.target)"
    }
}

struct Header {
    // Frame
    /// Size of the whole packet (header and payload)
    var size: UInt16 {
        switch type {
        case DeviceMessage.stateService:        return 41
        case DeviceMessage.stateHostInfo:       return 50
        case DeviceMessage.stateHostFirmware:   return 56
        case DeviceMessage.stateWifiInfo:       return 50
        case DeviceMessage.stateWifiFirmware:   return 56
        case DeviceMessage.setPower:            return 38
        case DeviceMessage.statePower:          return 38
        case DeviceMessage.setLabel:            return 68
        case DeviceMessage.stateLabel:          return 68
        case DeviceMessage.stateVersion:        return 48
        case DeviceMessage.stateInfo:           return 60
        case DeviceMessage.stateLocation:       return 92
        case DeviceMessage.stateGroup:          return 92
        case DeviceMessage.echoRequest:         return 100
        case DeviceMessage.echoResponse:        return 100
        case LightMessage.setColor:             return 49
        case LightMessage.state:                return 84
        case LightMessage.setPower:             return 42
        case LightMessage.statePower:           return 38
        case LightMessage.stateInfrared:        return 38
        case LightMessage.setInfrared:          return 38
        default:                                return 36
        }
    }
    var tagged: Bool   = false
    var source: UInt32 = 0
    
    // Frame address
    /// MAC address or 0 (broadcast)
    var target: Address
    var ack: Bool = false
    var res: Bool = false
    var sequence: UInt8 {
        return 0
    }
    
    // Protocol
    var type: LIFXMessageType
    
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
            target[7].toU8,
            target[6].toU8,
            target[5].toU8,
            target[4].toU8,
            target[3].toU8,
            target[2].toU8,
            target[1].toU8,
            target[0].toU8,
            0, 0, 0, 0, 0, 0,       // Frame address reserved
            flags,
            sequence,
            0, 0, 0, 0, 0, 0, 0, 0, // Protocol reserved
            type.message[0].toU8,
            type.message[1].toU8,
            0, 0                    // Protocol reserved
        ]
    }
    
    init(type: LIFXMessageType, target: Address?) {
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
        let rawValue = UnsafePointer(Array(bytes[32...33]))
            .withMemoryRebound(to: UInt16.self, capacity: 1, { $0.pointee })
        if let type: LIFXMessageType = rawValue > 100 ? LightMessage(rawValue: rawValue) :
                                                        DeviceMessage(rawValue: rawValue) {
            self.type = type
        } else {
            return nil
        }
        
        self.target = UnsafePointer(Array(bytes[8...15]))
            .withMemoryRebound(to: Address.self, capacity: 1, { $0.pointee })
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
