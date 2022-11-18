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

protocol ScriptCommand<C> {
    associatedtype C: ScriptCommand
    var id: UUID { get }
    var children: [C] { get set }
}

extension Array where Element: ScriptCommand<Element> {
    func commandWith(uuid: String) -> Element? {
        for command in self {
            if command.id.uuidString == uuid {
                return command
            }
            if let command = command.children.commandWith(uuid: uuid) {
                return command
            }
        }
        return nil
    }

    mutating func remove(source: Element) {
        for (index, command) in enumerated() {
            if command.id == source.id {
                remove(at: index)
                return
            }
            self[index].children.remove(source: source)
        }
    }

    @discardableResult
    mutating func insert(source: Element, before target: Element) -> Bool {
        for (index, command) in enumerated() {
            if command.id == target.id {
                insert(source, at: index)
                return true
            }
            if self[index].children.insert(source: source, before: target) {
                return true
            }
        }
        return false
    }

    @discardableResult
    mutating func insert(source: Element, inside target: Element) -> Bool {
        for (index, command) in enumerated() {
            if command.id == target.id {
                self[index].children.append(source)
                return true
            }
            if self[index].children.insert(source: source, inside: target) {
                return true
            }
        }
        return false
    }

    @discardableResult
    mutating func insert(source: Element, after target: Element) -> Bool {
        for (index, command) in enumerated() {
            if command.id == target.id {
                insert(source, at: index + 1)
                return true
            }
            if self[index].children.insert(source: source, after: target) {
                return true
            }
        }
        return false
    }
}
