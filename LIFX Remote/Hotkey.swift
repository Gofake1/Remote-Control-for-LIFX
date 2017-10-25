//
//  Hotkey.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 10/2/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Carbon
import Cocoa

private var hotkeyPressedEventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                                   eventKind: UInt32(kEventHotKeyPressed))
private let keyboardSource = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeRetainedValue()
private let signature: FourCharCode = {
    let string = "FAKE"
    var code: FourCharCode = 0
    for scalar in string.unicodeScalars {
        code = (code << 8) + (FourCharCode(scalar) & 255)
    }
    return code
}()

class Hotkey {
    class Monitor {
        static let shared = Monitor.new()
        private var blocks = [UInt32: () -> Void]()

        private static func new() -> Monitor {
            let monitor = Monitor()
            let handler = {
                (_: EventHandlerCallRef!, event: EventRef!, ptr: UnsafeMutableRawPointer!) -> OSStatus in
                UnsafeMutablePointer<Hotkey.Monitor>(OpaquePointer(ptr)).pointee.handleEvent(event)
                return noErr
            } as EventHandlerUPP
            let ptr = UnsafeMutablePointer<Monitor>.allocate(capacity: 1)
            ptr.initialize(to: monitor)
            let status = InstallEventHandler(GetEventDispatcherTarget(), handler, 1,
                                             &hotkeyPressedEventType, ptr, nil)
            guard status == noErr else { fatalError() }
            return monitor
        }

        func register(_ id: UInt32, _ block: @escaping () -> Void) {
            blocks[id] = block
        }

        func unregister(_ id: UInt32) {
            blocks[id] = nil
        }

        private func handleEvent(_ event: EventRef) {
            guard GetEventClass(event) == kEventClassKeyboard else { return }
            var hotkeyId = EventHotKeyID()
            let status = GetEventParameter(event, UInt32(kEventParamDirectObject), UInt32(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyId)
            guard status == noErr, let block = blocks[hotkeyId.id] else { fatalError() }
            block()
        }
    }

    struct Keys {
        var keyCode: UInt16
        var modifierFlags: NSEvent.ModifierFlags

        var displayString: String? {
            guard let keyCodeString = keyCode.displayString else { return nil }
            return modifierFlags.displayString + keyCodeString
        }
    }

    let keys: Keys
    private static var idCounter: UInt32 = 0
    private let id: UInt32
    private let hotkey: EventHotKeyRef!

    /// - postcondition: Registers `block` to monitor
    init(_ keys: Keys, _ block: @escaping () -> Void) {
        self.keys = keys
        id = Hotkey.idCounter
        Hotkey.idCounter += 1
        var hotkey: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(keys.keyCode), keys.modifierFlags.carbonMask,
                                         EventHotKeyID(signature: signature, id: id),
                                         GetEventDispatcherTarget(), OptionBits(0), &hotkey)
        guard status == noErr else { fatalError() }
        self.hotkey = hotkey
        Monitor.shared.register(id, block)
    }

    static func validate(_ keyCode: UInt16, _ modifiers: NSEvent.ModifierFlags) -> Bool {
        switch Int(keyCode) {
        case kVK_F1:    fallthrough
        case kVK_F2:    fallthrough
        case kVK_F3:    fallthrough
        case kVK_F4:    fallthrough
        case kVK_F5:    fallthrough
        case kVK_F6:    fallthrough
        case kVK_F7:    fallthrough
        case kVK_F8:    fallthrough
        case kVK_F9:    fallthrough
        case kVK_F10:   fallthrough
        case kVK_F11:   fallthrough
        case kVK_F12:   fallthrough
        case kVK_F13:   fallthrough
        case kVK_F14:   fallthrough
        case kVK_F15:   fallthrough
        case kVK_F16:   fallthrough
        case kVK_F17:   fallthrough
        case kVK_F18:   fallthrough
        case kVK_F19:   fallthrough
        case kVK_F20:
            return true
        default:
            return modifiers.contains(.command) || modifiers.contains(.control)
        }
    }

    deinit {
        UnregisterEventHotKey(hotkey)
        Monitor.shared.unregister(id)
    }
}

extension NSEvent.ModifierFlags {
    var carbonMask: UInt32 {
        return UInt32(contains(.command) ? cmdKey : 0) |
            UInt32(contains(.control) ? controlKey : 0) |
            UInt32(contains(.option) ? optionKey : 0) |
            UInt32(contains(.shift) ? shiftKey : 0)
    }

    var displayString: String {
        var str = ""
        if contains(.control) { str += "⌃" }
        if contains(.option)  { str += "⌥" }
        if contains(.shift)   { str += "⇧" }
        if contains(.command) { str += "⌘" }
        return str
    }
}

extension UInt16 {
    var displayString: String? {
        switch Int(self) {
        case kVK_F1:            return "F1"
        case kVK_F2:            return "F2"
        case kVK_F3:            return "F3"
        case kVK_F4:            return "F4"
        case kVK_F5:            return "F5"
        case kVK_F6:            return "F6"
        case kVK_F7:            return "F7"
        case kVK_F8:            return "F8"
        case kVK_F9:            return "F9"
        case kVK_F10:           return "F10"
        case kVK_F11:           return "F11"
        case kVK_F12:           return "F12"
        case kVK_F13:           return "F13"
        case kVK_F14:           return "F14"
        case kVK_F15:           return "F15"
        case kVK_F16:           return "F16"
        case kVK_F17:           return "F17"
        case kVK_F18:           return "F18"
        case kVK_F19:           return "F19"
        case kVK_F20:           return "F20"
        case kVK_LeftArrow:     return "←"
        case kVK_RightArrow:    return "→"
        case kVK_UpArrow:       return "↑"
        case kVK_DownArrow:     return "↓"
        default:
            let ptr = TISGetInputSourceProperty(keyboardSource, kTISPropertyUnicodeKeyLayoutData)!
            let layoutData = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
            var deadKeyState: UInt32 = 0
            var actualStringLength = 0
            var uniChars = [UniChar](repeating: 0, count: 4)
            let status = layoutData.withUnsafeBytes {
                UCKeyTranslate($0, self, UInt16(kUCKeyActionDisplay), 0x00000004, UInt32(LMGetKbdType()),
                               OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeyState, 4,
                               &actualStringLength, &uniChars)
            }
            guard status == noErr else { return nil }
            return String(utf16CodeUnits: uniChars, count: actualStringLength)
        }
    }
}

extension UInt32 {
    var modifierFlags: NSEvent.ModifierFlags {
        var flags = NSEvent.ModifierFlags()
        if self & UInt32(cmdKey) != 0 {
            flags.insert(.command)
        }
        if self & UInt32(controlKey) != 0 {
            flags.insert(.control)
        }
        if self & UInt32(optionKey) != 0 {
            flags.insert(.option)
        }
        if self & UInt32(shiftKey) != 0 {
            flags.insert(.shift)
        }
        return flags
    }
}
