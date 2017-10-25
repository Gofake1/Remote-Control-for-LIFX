//
//  HotkeyView.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 10/5/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Carbon
import Cocoa

protocol HotkeyViewDelegate: class {
    func hotkeyDidChange(_ keys: Hotkey.Keys)
}

/// Turns keyboard input into `Hotkey.Keys`
class HotkeyView: NSView {
    weak var delegate: HotkeyViewDelegate?
    var keysValue: Hotkey.Keys? {
        didSet {
            needsDisplay = true
        }
    }
    private var keyDownEventMonitor: Any?
    private let buttonCell: NSButtonCell = {
        let cell = NSButtonCell()
        cell.setButtonType(.pushOnPushOff)
        cell.alignment = .center
        cell.backgroundColor = NSColor.clear
        cell.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        cell.isBordered = false
        cell.isEnabled = true
        cell.state = .off
        return cell
    }()

    override var focusRingMaskBounds: NSRect {
        return bounds
    }

    override func draw(_ dirtyRect: NSRect) {
        buttonCell.title = keysValue?.displayString ?? "None"
        buttonCell.draw(withFrame: bounds, in: self)
    }

    override func drawFocusRingMask() {
        buttonCell.drawFocusRingMask(withFrame: bounds, in: self)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        activateKeyDownMonitoring()
    }

    override func resignFirstResponder() -> Bool {
        deactivateKeyDownMonitoring()
        return true
    }

    func activateKeyDownMonitoring() {
        keyDownEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) {
            [weak self] (event) -> NSEvent? in
            switch Int(event.keyCode) {
            case kVK_ANSI_KeypadClear:  fallthrough
            case kVK_Delete:            fallthrough
            case kVK_Escape:            fallthrough
            case kVK_ForwardDelete:     fallthrough
            case kVK_Help:              fallthrough
            case kVK_Home:              fallthrough
            case kVK_Return:            fallthrough
            case kVK_Space:             fallthrough
            case kVK_Tab:
                return event
            case kVK_Command:   fallthrough
            case kVK_Control:   fallthrough
            case kVK_Shift:     fallthrough
            case kVK_Option:
                return nil
            default:
                guard Hotkey.validate(event.keyCode, event.modifierFlags) else { return nil }
                let keys = Hotkey.Keys(keyCode: event.keyCode, modifierFlags: event.modifierFlags)
                self?.delegate?.hotkeyDidChange(keys)
                self?.keysValue = keys
                return nil
            }
        }
    }

    func deactivateKeyDownMonitoring() {
        guard let monitor = keyDownEventMonitor else { return }
        NSEvent.removeMonitor(monitor)
    }
}
