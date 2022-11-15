//
//  ScriptCommand.swift
//  BTrain
//
//  Created by Jean Bovet on 11/14/22.
//

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
