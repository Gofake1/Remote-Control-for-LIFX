//
//  CSV.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 1/24/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

protocol CSVEncodable {
    /// Return `nil` if type should not be encoded
    var csvLine: CSV.Line? { get }
}

extension Array where Element: CSVEncodable {
    func encodeCSV(appendTo csv: CSV) {
        forEach {
            if let line = $0.csvLine {
                csv.append(line: line)
            }
        }
    }
}

class CSV {

    struct Line {
        var csvString: String {
            return values.joined(separator: ",")
        }

        var values: [String]

        init() {
            self.values = []
        }

        init(_ string: String) {
            self.values = string.components(separatedBy: ",")
        }

        init(_ values: String...) {
            self.values = values
        }

        mutating func append(_ value: String) {
            self.values.append(value)
        }
    }

    var lines = [Line]()

    init(_ document: String? = nil) {
        if let document = document {
            for line in document.components(separatedBy: "\n") {
                self.lines.append(Line(line))
            }
        }
    }

    func append(line: Line) {
        lines.append(line)
    }

    func append(lineString: String) {
        lines.append(Line(lineString))
    }

    func write(to path: String) throws {
        var str = ""
        lines.forEach { str += $0.csvString + "\n" }
        try str.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
