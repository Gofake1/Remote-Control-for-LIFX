//
//  KeyBinding.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 10/9/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa

protocol KeyBindingBlockProvider: class {
    func brightnessKeyBinding(_ value: Int) -> (() -> Void)
    func colorKeyBinding(_ value: NSColor) -> (() -> Void)
    func powerKeyBinding(_ value: LIFXLight.PowerState) -> (() -> Void)
}

extension LIFXDeviceGroup: KeyBindingBlockProvider {
    func brightnessKeyBinding(_ value: Int) -> (() -> Void) {
        return { [weak self] in
            guard var color = self?.color else { return }
            color.brightness = UInt16(percentage: value)
            self?.setColor(color)
        }
    }

    func colorKeyBinding(_ value: NSColor) -> (() -> Void) {
        return { [weak self] in self?.setColor(LIFXLight.Color(nsColor: value)) }
    }

    func powerKeyBinding(_ value: LIFXDevice.PowerState) -> (() -> Void) {
        return { [weak self] in self?.setPower(value) }
    }
}

extension LIFXLight: KeyBindingBlockProvider {
    func brightnessKeyBinding(_ value: Int) -> (() -> Void) {
        return { [weak self] in
            guard var color = self?.color else { return }
            color.brightness = UInt16(percentage: value)
            self?.setColor(color)
        }
    }

    func colorKeyBinding(_ value: NSColor) -> (() -> Void) {
        return { [weak self] in self?.setColor(LIFXLight.Color(nsColor: value)) }
    }

    func powerKeyBinding(_ value: LIFXDevice.PowerState) -> (() -> Void) {
        return { [weak self] in self?.setPower(value) }
    }
}

class KeyBinding: NSObject {
    enum CommandActionKind: String {
        case brightness
        case color
        case power

        var index: Int {
            switch self {
            case .brightness:   return 0
            case .color:        return 1
            case .power:        return 2
            }
        }

        init?(index: Int) {
            switch index {
            case 0:     self = .brightness
            case 1:     self = .color
            case 2:     self = .power
            default:    return nil
            }
        }
    }

    enum CommandTargetKind: String {
        case device
        case group
    }

    @objc dynamic var commandActionIndex = -1 {
        didSet {
            switch commandActionIndex {
            case 0:
                commandActionValue = commandActionBrightnessValue
            case 1:
                commandActionValue = commandActionColorValue
            case 2:
                commandActionValue = LIFXLight.PowerState(index: commandActionPowerValueIndex)
            default:
                fatalError()
            }
        }
    }
    @objc dynamic var commandActionBrightnessValue = 50 {
        didSet {
            commandActionValue = commandActionBrightnessValue
        }
    }
    @objc dynamic var commandActionColorValue: NSColor? {
        didSet {
            guard let color = commandActionColorValue else { return }
            commandActionValue = color
        }
    }
    @objc dynamic var commandActionPowerValueIndex = -1 {
        didSet {
            guard let powerState = LIFXLight.PowerState(index: commandActionPowerValueIndex)
                else { return }
            commandActionValue = powerState
        }
    }
    /// Represents a `LIFXDevice` or `LIFXGroup`
    @objc dynamic weak var commandTargetObject: AnyObject? {
        didSet {
            setBlock()
        }
    }
    private var commandActionValue: Any? {
        didSet {
            setBlock()
        }
    }
    var hotkeyKeys: Hotkey.Keys? {
        didSet {
            setHotkey()
        }
    }
    private var hotkeyBlock: (() -> Void)?
    private var hotkey: Hotkey?

    convenience init?(target: AnyObject, action: CommandActionKind, actionValue: String, keyCode: UInt16,
          modifierFlags: NSEvent.ModifierFlags)
    {
        self.init()
        commandTargetObject = target
        commandActionIndex = action.index
        switch action {
        case .brightness:
            guard let brightness = Int(actionValue) else { return nil }
            commandActionBrightnessValue = brightness
        case .color:
            let hsbk = actionValue.split(separator: " ")
            guard hsbk.count == 4,
                let h = UInt16(hsbk[0]),
                let s = UInt16(hsbk[1]),
                let b = UInt16(hsbk[2]),
                let k = UInt16(hsbk[3])
                else { return nil }
            commandActionColorValue = LIFXLight.Color(hue: h, saturation: s, brightness: b, kelvin: k).nsColor
        case .power:
            guard let powerState = LIFXLight.PowerState(savedStateValue: actionValue) else { return nil }
            commandActionPowerValueIndex = powerState.index
        }
        hotkeyKeys = Hotkey.Keys(keyCode: keyCode, modifierFlags: modifierFlags)
    }

    func willBeRemoved() {
        hotkey = nil
    }

    /// - postcondition: Mutates `hotkeyBlock` and `hotkey`
    private func setBlock() {
        hotkey = nil
        guard let target = commandTargetObject as? KeyBindingBlockProvider,
            let value = commandActionValue
            else { return }
        switch value {
        case let brightness as Int:
            hotkeyBlock = target.brightnessKeyBinding(brightness)
        case let color as NSColor:
            hotkeyBlock = target.colorKeyBinding(color)
        case let powerState as LIFXLight.PowerState:
            hotkeyBlock = target.powerKeyBinding(powerState)
        default:
            fatalError()
        }
        setHotkey()
    }

    /// - postcondition: Mutates `hotkey`
    private func setHotkey() {
        guard let block = hotkeyBlock, let keys = hotkeyKeys else { return }
        hotkey = Hotkey(keys, block)
    }
}

extension KeyBinding: CSVEncodable {
    var csvLine: CSV.Line? {
        guard let target = commandTargetObject as? KeyBindingCommandTargetType,
            let actionKind = CommandActionKind(index: commandActionIndex),
            let hotkey = hotkey else { return nil }
        let targetKind = target.keyBindingCommandTargetSavedState.kind.rawValue
        let targetId = target.keyBindingCommandTargetSavedState.id
        let keyCode = String(hotkey.keys.keyCode)
        let modifiers = String(hotkey.keys.modifierFlags.carbonMask)
        let actionValue: String
        switch actionKind {
        case .brightness:
            actionValue = String(commandActionBrightnessValue)
        case .color:
            guard let color = commandActionColorValue else { return nil }
            actionValue = LIFXLight.Color(nsColor: color).savedStateValue
        case .power:
            guard let powerState = LIFXLight.PowerState(index: commandActionPowerValueIndex)
                else { return nil }
            actionValue = powerState.savedStateValue
        }
        return CSV.Line("hotkey", targetKind, targetId, keyCode, modifiers, actionKind.rawValue, actionValue)
    }
}

extension LIFXLight.Color {
    var savedStateValue: String {
        return "\(hue) \(saturation) \(brightness) \(kelvin)"
    }
}

extension LIFXLight.PowerState {
    var index: Int {
        switch self {
        case .enabled: return 0
        case .standby: return 1
        }
    }

    var savedStateValue: String {
        switch self {
        case .enabled: return "on"
        case .standby: return "off"
        }
    }

    init?(index: Int) {
        switch index {
        case 0:     self = .enabled
        case 1:     self = .standby
        default:    return nil
        }
    }

    init?(savedStateValue: String) {
        switch savedStateValue {
        case "on":  self = .enabled
        case "off": self = .standby
        default:    return nil
        }
    }
}
