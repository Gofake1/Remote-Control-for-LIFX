//
//  LIFXModel.swift
//  LIFX Remote
//
//  Created by David Wu on 6/17/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Darwin
import Cocoa

struct LIFXModel {
    enum NetworkState {
        case inactive
        case activeSearching
        case activeWorking
    }
    
    var network = LIFXNetworkController()
    var state: NetworkState = .inactive
    var devices: [LIFXDevice] = []
    
    func getDevice(withLabel label: String) -> LIFXDevice? {
        for device in devices {
            if label == device.label {
                return device
            }
        }
        return nil
    }
    
    mutating func scan(_ completionHandler: @escaping () -> Void) {
        //network.send(Packet(tagged: true, target: 0, ack: false, res: true, type: 2))
        add(device: LIFXLight(network: network))
        let foo2 = LIFXLight(network: network)
        foo2.label = "Foo 2"
        foo2.color = nil
        add(device: foo2)
        completionHandler()
    }
    
    mutating func add(device: LIFXDevice) {
        devices.append(device)
    }
    
    mutating func removeDevice(withLabel label: String) {
        devices = devices.filter { (device) -> Bool in
            return device.label != label
        }
    }
    
    func change(device: LIFXDevice, state: LIFXDevice.PowerState) {
        if let _device = devices.first(where: { (_device) -> Bool in
            return device == _device
        }) {
            _device.power = state
        }
    }
    
    func changeAllDevices(state: LIFXDevice.PowerState) {
        for device in devices {
            device.power = state
        }
    }
}

class LIFXNetworkController {
//    var socket: CFSocket?
    var sock: Int32
    
//    var callback: @convention(c)(CFSocket!, CFSocketCallBackType, CFData!, UnsafePointer<Void>, UnsafeMutablePointer<Void>) -> Void = {
//        (s, callbackType, address, data, info) in
//        print(data)
//    }
    
    init() {
//        self.socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_DGRAM, IPPROTO_UDP, CFSocketCallBackType.DataCallBack.rawValue, callback, nil)
//        let socketSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, self.socket, 0)
//        CFRunLoopAddSource(CFRunLoopGetCurrent(), socketSource, kCFRunLoopDefaultMode)
        self.sock = socket(PF_INET, SOCK_DGRAM, 0)
        if self.sock == -1 {
            perror("socket error")
        }
        var broadcastFlag = 1
        let optErr = setsockopt(self.sock, SOL_SOCKET, SO_BROADCAST, &broadcastFlag, socklen_t(MemoryLayout<Int>.size))
        if optErr == -1 {
            perror("setsockopt error")
        }
    }
    
    func send(_ packet: Packet, toDevice device: LIFXDevice? = nil) {
//        let data = NSData(packet)
//        var sin = sockaddr_in()
//        sin.sin_len = UInt8(sizeof(sockaddr_in))
//        sin.sin_family = sa_family_t(AF_INET)
//        sin.sin_port = UInt16(56700).bigEndian //UInt16(device!.port)
//        inet_aton("255.255.255.255", &sin.sin_addr)
//        var sin_data: CFData?
//        withUnsafePointer(&sin) {
//            sin_data = CFDataCreate(kCFAllocatorDefault, UnsafePointer($0), sizeof(sockaddr_in))
//            let error = CFSocketSendData(self.socket, sin_data, data as CFData, 5) // 5 second timeout
//            if error != .Success {
//                switch error {
//                case .Timeout:
//                    print("Socket timed out")
//                case .Error:
//                    print("Socket error")
//                default: break
//                }
//            }
//        }
        let data = Data(packet)
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(56700).bigEndian
        inet_aton("255.255.255.255", &addr.sin_addr)
        withUnsafePointer(to: &addr) {
            let n = Darwin.sendto(self.sock, (data as NSData).bytes, data.count, 0, unsafeBitCast($0, to: UnsafePointer<sockaddr>.self), socklen_t(MemoryLayout<sockaddr_in>.size))
            if n == -1 {
                perror("sendto error")
            }
        }
        
        let res = [UInt8](repeating: 0, count: 128)
        var resLen = socklen_t(MemoryLayout<sockaddr>.size)
        withUnsafePointer(to: &addr) {
            let n = Darwin.recvfrom(self.sock, UnsafeMutablePointer(mutating: res), res.count, 0, unsafeBitCast($0, to: UnsafeMutablePointer<sockaddr>.self), &resLen)
            if n == -1 {
                perror("recvfrom error")
            }
            print(res)
        }
    }
    
    func receive(_ packet: Packet, fromDevice device: LIFXDevice) {
        
    }
    
    func addDevice(_ device: LIFXDevice) {
        
    }
}

class LIFXDevice {
    enum Service {
        case udp
    }
    
    enum PowerState: UInt16 {
        case on  = 56700
        case off = 0
    }
    
    var network: LIFXNetworkController
    var service: Service = .udp
    var port:    UInt32 = 56700
    var address: String
    var label:   String {
        //get { return getLabel() }
        //set {}
        didSet {
            setLabel(label)
        }
    }
    var power:   PowerState = .off {
        //get { return getPower() }
        //set {}
        didSet {
            setPower(level: power.rawValue)
        }
    }
    
    init(network: LIFXNetworkController) {
        self.network = network
        self.address = ""
        self.label   = "Foo"
    }
    
    private func getPower() -> UInt16 {
        return 0
    }
    
    private func setPower(level: UInt16, duration: UInt32 = 0) {
        
    }
    
    fileprivate func getLabel() -> String {
        return "Foo"
    }
    
    fileprivate func setLabel(_ label: String) {
        
    }
    
    /*
    /// - returns: device service and port
    func getService() -> (Service, UInt32) {
        network.send(Packet(tagged: true, target: 0, ack: false, res: false, type: 0), toDevice: self)
    }
    
    /// - returns: host signal, tx, rx
    func getHostInfo() -> (Float32, UInt32, UInt32) {
        
    }
    
    /// - returns: host firmware build, version
    func getHostFirmware() -> (UInt64, UInt32) {
        
    }
    
    /// - returns: Wifi subsystem signal, tx, rx
    func getWifiInfo() -> (Float32, UInt32, UInt32) {
        
    }
    
    /// - returns: Wifi subsystem build, version
    func getWifiFirmware() -> (UInt64, UInt32) {
        
    }
    
    /// - returns: device hardware vendor, product, version
    func getVersion() -> (UInt32, UInt32, UInt32) {

    }
    
    /// - returns: device time, uptime, downtime
    func getInfo() -> (UInt64, UInt64, UInt64) {

    }
    
    /// - returns: device location, label, updated_at
    func getLocation() -> ([UInt8], String, UInt64) {

    }
    
    /// - returns: group, label, updated_at
    func getGroup() -> ([UInt8], String, UInt64) {

    }
    
    /// - returns: echoed payload
    func echoRequest(payload: [UInt8]) -> [UInt8] {

    }
    */
}

extension LIFXDevice: Equatable {
    static func ==(lhs: LIFXDevice, rhs: LIFXDevice) -> Bool {
        return lhs.label == rhs.label
    }
}

extension LIFXDevice: Hashable {
    var hashValue: Int {
        return label.hashValue
    }
}

class LIFXLight: LIFXDevice {
    struct Color {
        var hue:        UInt16
        var saturation: UInt16
        var brightness: UInt16
        var kelvin:     UInt16
    }
    
    var color: Color? = Color(hue: 128, saturation: 128, brightness: 128, kelvin: 0) //{
        //get { /*return self.getState().0*/ }
        //set {}
    //}
    
    override init(network: LIFXNetworkController) {
        super.init(network: network)
        self.color = Color(hue: 0, saturation: 0, brightness: 0, kelvin: 0)
    }
    
     /*
    override private func getPower() -> UInt16 {
        
    }

    override private func setPower(level: UInt16, duration: UInt32) {
        
    }
    
    /// - returns: light color, power, label
    func getState() -> (Color, UInt16, String) {
        
    }
    
    func setColor(color: Color, duration: UInt32) {
        self.color = color
    }
    */
}

extension NSColor {
    convenience init?(from color: LIFXLight.Color?) {
        if let _ = color {
            self.init(hue:        0.5, //CGFloat(color.hue),
                      saturation: 0.6, //CGFloat(color.saturation),
                      brightness: 0.7, //CGFloat(color.brightness),
                      alpha:      1.0)
        } else {
            return nil
        }
    }
}
