//
//  LIFXPacket.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 6/16/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

struct LIFXPacket {
    let header: Header
    let payload: Payload?
    let originIpAddress: String?
    
    /// - parameter target: MAC address or nil (all devices)
    init(kind: Kind, with payload: [UInt8]? = nil, to target: Address? = nil) {
        header = Header(kind: kind, target: target)
        self.payload = Payload(bytes: payload)
        originIpAddress = nil
    }
    
    init?(bytes: [UInt8], originIpAddress: String) {
        guard bytes.count >= 36, let header = Header(bytes: Array(bytes[0...35])) else { return nil }
        self.header = header
        guard bytes.count == header.size else { return nil }
        payload = Payload(bytes: Array(bytes[36..<Int(header.size)]))
        self.originIpAddress = originIpAddress
    }
}

extension LIFXPacket: CustomStringConvertible {
    var description: String {
        return "\(header.kind) packet to \(header.target)"
    }
}

extension LIFXPacket {
    enum Kind: UInt16 {
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
        case getPowerDevice     = 20
        case setPowerDevice     = 21
        case statePowerDevice   = 22
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
        
        case getState           = 101
        case setColor           = 102
        case state              = 107
        case getPowerLight      = 116
        case setPowerLight      = 117
        case statePowerLight    = 118
        case getInfrared        = 120
        case stateInfrared      = 121
        case setInfrared        = 122
    }
    
    // MARK: -
    
    struct Header {
        // MARK: - Frame
        /// Size of the whole packet (header and payload)
        var size: UInt16 {
            switch kind {
            case .stateService:         return 41
            case .stateHostInfo:        return 50
            case .stateHostFirmware:    return 56
            case .stateWifiInfo:        return 50
            case .stateWifiFirmware:    return 56
            case .setPowerDevice:       return 38
            case .statePowerDevice:     return 38
            case .setLabel:             return 68
            case .stateLabel:           return 68
            case .stateVersion:         return 48
            case .stateInfo:            return 60
            case .stateLocation:        return 92
            case .stateGroup:           return 92
            case .echoRequest:          return 100
            case .echoResponse:         return 100
            case .setColor:             return 49
            case .state:                return 84
            case .setPowerLight:        return 42
            case .statePowerLight:      return 38
            case .stateInfrared:        return 38
            case .setInfrared:          return 38
            default:                    return 36
            }
        }
        var tagged = false
        var source = UInt32(0)
        
        // MARK: - Frame address
        /// Device's MAC address (or 0 for all devices) in big-endian order
        var target: Address
        var ack = false
        var res = false
        var sequence: UInt8 {
            return 0
        }
        
        // MARK: - Protocol
        var kind: Kind
        
        // MARK: -
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
                kind.rawValue[0].toU8,
                kind.rawValue[1].toU8,
                0, 0                    // Protocol reserved
            ]
        }
        
        init(kind: Kind, target: Address?) {
            self.kind = kind
            self.target = target ?? 0
            
            switch kind {
            case .getService:
                tagged = true
                res    = true
            case .getHostInfo:      fallthrough
            case .getHostFirmware:  fallthrough
            case .getWifiInfo:      fallthrough
            case .getWifiFirmware:  fallthrough
            case .getPowerDevice:   fallthrough
            case .getLabel:         fallthrough
            case .getVersion:       fallthrough
            case .getInfo:          fallthrough
            case .getLocation:      fallthrough
            case .getGroup:         fallthrough
            case .echoRequest:      fallthrough
            case .getState:         fallthrough
            case .getPowerLight:    fallthrough
            case .getInfrared:
                res = true
            default:
                break
            }
        }
        
        init?(bytes: [UInt8]) {
            let rawValue = UnsafePointer(Array(bytes[32...33]))
                .withMemoryRebound(to: UInt16.self, capacity: 1) { $0.pointee }
            guard let kind = Kind(rawValue: rawValue) else { return nil }
            self.kind = kind
            target = UnsafePointer(Array(bytes[8...15]))
                .withMemoryRebound(to: Address.self, capacity: 1, { $0.pointee }).bigEndian
        }
    }
    
    // MARK: -
    
    struct Payload {
        let bytes: [UInt8]
        
        init?(bytes: [UInt8]?) {
            guard let bytes = bytes else { return nil }
            self.bytes = bytes
        }
    }
}
