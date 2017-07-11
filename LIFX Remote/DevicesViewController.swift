//
//  DevicesViewController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 1/7/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa

class DevicesViewController: NSViewController {

    @objc private unowned let model = LIFXModel.shared

    override func viewDidLoad() {
        preferredContentSize = NSSize(width: 450, height: 300)
    }

    @IBAction func searchForDevices(_ sender: NSButton) {
        model.discover()
    }
}
