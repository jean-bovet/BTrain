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
    mutating func insert(source: Element, target: Element, position: ScriptDropLinePosition) -> Bool {
        for (index, command) in enumerated() {
            if command.id == target.id {
                switch position {
                case .before:
                    insert(source, at: index)
                case .inside:
                    self[index].children.append(source)
                case .after:
                    insert(source, at: index + 1)
                }
                return true
            }
            if self[index].children.insert(source: source, target: target, position: position) {
                return true
            }
        }
        return false
    }
        
}
