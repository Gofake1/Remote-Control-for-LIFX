//
//  KeyBindingsViewController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 10/5/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa

class KeyBindingsViewController: NSViewController {
    @IBOutlet weak var arrayController: NSArrayController!

    @objc private let model = Model.shared

    @IBAction func addKeyBinding(_ sender: NSButton) {
        Model.shared.add(keyBinding: KeyBinding())
    }

    @IBAction func removeKeyBinding(_ sender: NSButton) {
        Model.shared.removeKeyBinding(at: arrayController.selectionIndex)
    }
}
