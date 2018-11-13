//
//  KeyBindingHotkeyTableCellView.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 10/12/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa

class KeyBindingHotkeyTableCellView: NSTableCellView {
    @IBOutlet weak var hotkeyView: HotkeyView!

    override var objectValue: Any? {
        didSet {
            guard let keyBinding = objectValue as? KeyBinding else { return }
            hotkeyView.keysValue = keyBinding.hotkeyKeys
        }
    }

    override func awakeFromNib() {
        hotkeyView.delegate = self
    }

    override func prepareForReuse() {
        hotkeyView.keysValue = nil
    }
}

extension KeyBindingHotkeyTableCellView: HotkeyViewDelegate {
    func hotkeyDidChange(_ keys: Hotkey.Keys) {
        guard let keyBinding = objectValue as? KeyBinding else { return }
        keyBinding.hotkeyKeys = keys
    }
}
