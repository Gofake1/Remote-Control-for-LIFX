//
//  Logging.swift
//  Remote Control for LIFX
//
//  Created by David on 4/1/18.
//  Copyright © 2018 Gofake1. All rights reserved.
//

import Foundation

final class Logging {
    private static var logger: LoggerType = PrintLogger()
    
    static func log(_ error: Error) {
        logger.log(error)
    }
    
    static func log(_ message: String) {
        logger.log(message)
    }
}

protocol LoggerType {
    func log(_ error: Error)
    func log(_ message: String)
}

extension Logging {
    final class PrintLogger {}
}

extension Logging.PrintLogger: LoggerType {
    func log(_ error: Error) {
        print("!!!", error)
    }
    
    func log(_ message: String) {
        print("---", message)
    }
}
