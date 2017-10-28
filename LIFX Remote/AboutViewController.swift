//
//  AboutViewController.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 1/7/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa

class AboutViewController: NSViewController {
    // Workaround: macOS 10.11 and earlier do not support weak references to `NSTextView`
    @IBOutlet var acknowledgementsText: NSTextView!

    override func viewDidLoad() {
        preferredContentSize = NSSize(width: 450, height: 300)
        if let path = Bundle.main.path(forResource: "Acknowledgements", ofType: "rtf") {
            acknowledgementsText.readRTFD(fromFile: path)
        }
    }

    @IBAction func openWebsite(_ sender: NSButton) {
        NSWorkspace.shared.open(URL(string: "https://gofake1.net/projects/lifx_remote.html")!)
    }
}
