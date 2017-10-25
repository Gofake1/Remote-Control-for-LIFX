//
//  ValueTransformers.swift
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
        return bool ? NSColor.controlTextColor : NSColor.disabledControlTextColor
    }
}

class NotEqual: ValueTransformer {
    private let int: Int

    init(_ int: Int) {
        self.int = int
        super.init()
    }

    override class func allowsReverseTransformation() -> Bool {
        return false
    }

    override class func transformedValueClass() -> AnyClass {
        return NSNumber.self
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let int = value as? Int else { return nil }
        return NSNumber(booleanLiteral: int != self.int)
    }
}

class AppendString: ValueTransformer {
    private let appendedString: String

    init(_ appendedString: String) {
        self.appendedString = appendedString
    }

    override class func allowsReverseTransformation() -> Bool {
        return false
    }

    override class func transformedValueClass() -> AnyClass {
        return NSString.self
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let string = value as? String else { return nil }
        return NSString(string: string+appendedString)
    }
}
