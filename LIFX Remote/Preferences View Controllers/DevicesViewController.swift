//
//  DevicesViewController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 1/7/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa

class DevicesViewController: NSViewController {
    @IBOutlet weak var arrayController: NSArrayController!
    
    @objc private let model = Model.shared

    override func viewDidLoad() {
        preferredContentSize = NSSize(width: 450, height: 300)
        // Workaround: initially disable 'Forget Devices' button
        arrayController.setSelectedObjects([])
    }

    @IBAction func forgetDevice(_ sender: NSButton) {
        Model.shared.removeDevice(at: arrayController.selectionIndex)
    }

    @IBAction func searchForDevices(_ sender: NSButton) {
        Model.shared.refresh()
    }
}
