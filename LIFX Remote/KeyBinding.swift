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

extension LIFXGroup: KeyBindingBlockProvider {
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

    override var description: String {
        let targetKind = promisedCommandTarget?.kind.rawValue ?? "nil"
        let targetId = promisedCommandTarget?.id ?? "nil"
        let actionKind = promisedCommandAction?.kind.rawValue ?? "nil"
        let actionValue = promisedCommandAction?.value ?? "nil"
        return "hotkey: { target: \(targetKind) \(targetId), action: \(actionKind) \(actionValue) }"
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
    private var promisedCommandTarget: (kind: CommandTargetKind, id: String)?
    private var promisedCommandAction: (kind: CommandActionKind, value: String)?

    convenience init(csvLine: CSV.Line, version: Int) {
        self.init()
        switch version {
        case 3:
            guard csvLine.values.count >= 6,
                let keyCode = UInt16(csvLine.values[3]),
                let modifierFlags = UInt32(csvLine.values[4])?.modifierFlags,
                Hotkey.validate(keyCode, modifierFlags),
                let targetKind = CommandTargetKind(rawValue: csvLine.values[1]),
                let actionKind = CommandActionKind(rawValue: csvLine.values[5])
                else { return }
            promisedCommandTarget = (targetKind, csvLine.values[2])
            hotkeyKeys = Hotkey.Keys(keyCode: keyCode, modifierFlags: modifierFlags)
            promisedCommandAction = (actionKind, csvLine.values[6])
        default:
            return
        }
    }

    /// Finish initialization from saved state after LIFX objects created
    func restore(from model: LIFXModel) {
        guard let promisedCommandTarget = promisedCommandTarget,
            let promisedCommandAction = promisedCommandAction else { return }
        switch promisedCommandTarget.kind {
        case .device:
            guard let address = Address(promisedCommandTarget.id) else { return }
            commandTargetObject = model.device(for: address)
        case .group:
            commandTargetObject = model.group(for: promisedCommandTarget.id)
        }
        commandActionIndex = promisedCommandAction.kind.index
        switch promisedCommandAction.kind {
        case .brightness:
            guard let brightness = Int(promisedCommandAction.value) else { return }
            commandActionBrightnessValue = brightness
        case .color:
            let tokens = promisedCommandAction.value.split(separator: " ")
            guard tokens.count == 4,
                let hue = UInt16(tokens[0]),
                let saturation = UInt16(tokens[1]),
                let brightness = UInt16(tokens[2]),
                let kelvin = UInt16(tokens[3])
                else { return }
            commandActionColorValue = LIFXLight.Color(hue: hue, saturation: saturation,
                                                      brightness: brightness, kelvin: kelvin).nsColor
        case .power:
            guard let powerState = LIFXLight.PowerState(savedStateValue: promisedCommandAction.value)
                else { return }
            commandActionPowerValueIndex = powerState.index
        }
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
