//
//  AppDelegate.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 6/16/16.
//  Copyright © 2016 Gofake1. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject {

    private lazy var preferences: NSWindowController? = {
        return NSStoryboard(name: NSStoryboard.Name(rawValue: "Preferences"), bundle: nil)
            .instantiateInitialController() as? NSWindowController
    }()

    @IBAction func showPreferences(_ sender: NSMenuItem) {
        NSApp.activate(ignoringOtherApps: true)
        preferences?.showWindow(nil)
    }

    override init() {
        super.init()
        let booleanToColor = BooleanToColor()
        ValueTransformer.setValueTransformer(booleanToColor,
                                             forName: NSValueTransformerName(rawValue: "BooleanToColor"))
    }
}

extension AppDelegate: NSApplicationDelegate {

    func applicationWillTerminate(_ notification: Notification) {
        LIFXModel.shared.saveState()
    }
}
