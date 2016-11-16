//
//  LIFXProtocol.swift
//  LIFX Remote
//
//  Created by David Wu on 6/16/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Foundation

extension Data {
    init(_ packet: Packet) {
        let bytes: [UInt8] = packet.header.bytes + packet.payload.bytes
        self.init(bytes: bytes)
    }
}

struct Packet {
    var header: Header
    var payload: Payload
    
    init(tagged: Bool, target: UInt64, ack: Bool, res: Bool, type: UInt16) {
        self.header = Header(tagged: tagged, target: target, ack: ack, res: res, type: type)
        self.payload = Payload()
    }
}

struct Header {
    // Frame
    var size: UInt16 {
        get { return 36 }
    }
    var tagged: Bool
    //var source: UInt32
    // Frame address
    var target: UInt64 // MAC address or 0 (broadcast)
    var ack: Bool
    var res: Bool
    //var sequence: UInt8
    // Protocol
    var type: UInt16
    
    var bytes: [UInt8] {
        get {
            var flags: UInt8 = 0
            if self.ack {
                flags = flags.setb6(1)
            }
            if self.res {
                flags = flags.setb7(1)
            }
            return [
                self.size[0].toU8,
                self.size[1].toU8,
                self.tagged ? 0b00110100 : 0b00010100,
                0,
                0, 0, 0, 0,
                self.target[0].toU8,
                self.target[1].toU8,
                self.target[2].toU8,
                self.target[3].toU8,
                self.target[4].toU8,
                self.target[5].toU8,
                self.target[6].toU8,
                self.target[7].toU8,
                0, 0, 0, 0, 0, 0,
                flags,
                0,
                0, 0, 0, 0, 0, 0, 0, 0,
                self.type[0].toU8,
                self.type[1].toU8,
                0, 0
            ]
        }
    }
}

struct Payload {
    var bytes: [UInt8] {
        get {
            return [0]
        }
    }
}
