//
//  BooleanToColor.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 7/15/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa

class BooleanToColor: ValueTransformer {

    override class func allowsReverseTransformation() -> Bool {
        return false
    }

    override class func transformedValueClass() -> AnyClass {
        return NSColor.self
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let bool = value as? Bool else { return nil }
        switch bool {
        case true:
            return NSColor.controlTextColor
        case false:
            return NSColor.disabledControlTextColor
        }
    }
}
