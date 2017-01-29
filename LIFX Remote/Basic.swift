//
//  Basic.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 1/17/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Foundation

enum Either<A, B> {
    case left(A)
    case right(B)
}
