//
//  MainMenu.swift
//  BTrain
//
//  Created by Jean Bovet on 5/14/22.
//

import SwiftUI

struct MenuCommands: Commands {

    var body: some Commands {
        CommandGroup(after: CommandGroupPlacement.sidebar) {
            CommandSelectedView(viewType: .overview, label: "Switchboard").keyboardShortcut("0", modifiers: [.command])
            CommandSelectedView(viewType: .routes, label: "Routes").keyboardShortcut("1", modifiers: [.command])
            CommandSelectedView(viewType: .trains, label: "Trains").keyboardShortcut("2", modifiers: [.command])
            CommandSelectedView(viewType: .stations, label: "Stations").keyboardShortcut("3", modifiers: [.command])
            CommandSelectedView(viewType: .blocks, label: "Blocks").keyboardShortcut("4", modifiers: [.command])
            CommandSelectedView(viewType: .turnouts, label: "Turnouts").keyboardShortcut("5", modifiers: [.command])
            CommandSelectedView(viewType: .feedback, label: "Feedback").keyboardShortcut("6", modifiers: [.command])
            Divider()
            CommandSelectedView(viewType: .speed, label: "Speed Measurements")
            Divider()
        }
    }
}
