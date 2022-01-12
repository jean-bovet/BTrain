//
//  CommandTypes.swift
//  BTrain
//
//  Created by Jean Bovet on 1/11/22.
//

import Foundation

// This type defines the speed value express in the unit that the CAN-message
// expects the speed to be provided. This value is specific to each Digital Controller,
// for example for the CS3, the speed value is expected to between 0 and 1000.
struct SpeedValue: Equatable {
    var value: UInt16
    static let zero = SpeedValue(value: 0)
}

// Define the type of speed when expressed in number of decoder steps
struct SpeedStep: Equatable {
    var value: UInt16
    static let zero = SpeedStep(value: 0)
}
