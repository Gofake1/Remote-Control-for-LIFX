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
    private lazy var preferences = NSStoryboard(name: NSStoryboard.Name("Preferences"), bundle: nil)
        .instantiateInitialController() as? NSWindowController

    override init() {
        super.init()
        ValueTransformer.setValueTransformer(BooleanToColor(), forName: .init("BooleanToColor"))
        ValueTransformer.setValueTransformer(NotEqual(0), forName: .init("NotEqualTo0"))
        ValueTransformer.setValueTransformer(NotEqual(1), forName: .init("NotEqualTo1"))
        ValueTransformer.setValueTransformer(NotEqual(2), forName: .init("NotEqualTo2"))
        ValueTransformer.setValueTransformer(AppendString(" Settings"), forName: .init("AppendStringSettings"))
    }
    
    @IBAction func showPreferences(_ sender: NSMenuItem) {
        NSApp.activate(ignoringOtherApps: true)
        preferences?.showWindow(nil)
    }
}

extension AppDelegate: NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Model.shared.setup()
        Model.shared.refresh()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Persisting.persist(Model.shared)
    }
}
