// Copyright 2021-22 Jean Bovet
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Foundation

class CS2DocumentParser {
    let lines: [String]
    var lineIndex = 0

    var line: String? {
        if lineIndex < lines.count {
            return lines[lineIndex]
        } else {
            return nil
        }
    }

    init(text: String) {
        lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    func parseSectionAndIgnore() {
        while let line = line, line.starts(with: ".") {
            lineIndex += 1
        }
    }

    func valueFor(field: String) -> String? {
        guard let line = line else {
            return nil
        }

        if line.starts(with: field) {
            return String(line[field.endIndex...])
        } else {
            return nil
        }
    }

    func matchesSectionName() -> String? {
        guard let line = line else {
            return nil
        }

        if !line.starts(with: ".") {
            lineIndex += 1
            return line
        } else {
            return nil
        }
    }

    func matches(_ text: String) -> Bool {
        if let line = line {
            if line == text {
                lineIndex += 1
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }
}
