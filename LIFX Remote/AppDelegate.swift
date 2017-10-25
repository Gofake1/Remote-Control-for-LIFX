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
        ValueTransformer.setValueTransformer(BooleanToColor(),
                                             forName: NSValueTransformerName(rawValue: "BooleanToColor"))
        ValueTransformer.setValueTransformer(NotEqual(0),
                                             forName: NSValueTransformerName(rawValue: "NotEqualTo0"))
        ValueTransformer.setValueTransformer(NotEqual(1),
                                             forName: NSValueTransformerName(rawValue: "NotEqualTo1"))
        ValueTransformer.setValueTransformer(NotEqual(2),
                                             forName: NSValueTransformerName(rawValue: "NotEqualTo2"))
        ValueTransformer.setValueTransformer(AppendString(" Settings"),
                                             forName: NSValueTransformerName(rawValue: "AppendStringSettings"))
    }
}

extension AppDelegate: NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        LIFXModel.shared.saveState()
    }
}
