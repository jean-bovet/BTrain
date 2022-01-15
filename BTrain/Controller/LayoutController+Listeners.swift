//
//  LayoutController+Listeners.swift
//  BTrain
//
//  Created by Jean Bovet on 1/14/22.
//

import Foundation

extension LayoutController {
    
    func interfaceChanged() {
        registerForFeedbackChange()
        registerForSpeedChange()
        registerForDirectionChange()
        registerForTurnoutChange()
    }
    
    func registerForFeedbackChange() {
        interface?.register(forFeedbackChange: { [weak self] deviceID, contactID, value in
            guard let layout = self?.layout else {
                return
            }
            if let feedback = layout.feedbacks.find(deviceID: deviceID, contactID: contactID) {
                feedback.detected = value == 1
            }
        })
    }
                
    func registerForSpeedChange() {
        interface?.register(forSpeedChange: { [weak self] address, decoder, value in
            guard let layout = self?.layout, let interface = self?.interface else {
                return
            }

            DispatchQueue.main.async {
                if let train = layout.trains.find(address: address, decoder: decoder) {
                    train.speed.steps = interface.speedSteps(for: value, decoder: train.decoder)
                }
            }
        })
    }
    
    func registerForDirectionChange() {
        interface?.register(forDirectionChange: { [weak self] address, decoder, direction in
            guard let layout = self?.layout else {
                return
            }

            DispatchQueue.main.async {
                if let train = layout.trains.find(address: address, decoder: decoder) {
                    switch(direction) {
                    case .forward:
                        if train.directionForward == false {
                            train.directionForward = true
                            try? layout.toggleTrainDirectionInBlock(train)
                        }
                    case .backward:
                        if train.directionForward {
                            train.directionForward = false
                            try? layout.toggleTrainDirectionInBlock(train)
                        }
                    case .unknown:
                        BTLogger.error("Unknown direction \(direction) for \(address.toHex())")
                    }
                } else {
                    BTLogger.error("Unknown address \(address.toHex()) for change in direction event")
                }
            }
        })
    }
    
    func registerForTurnoutChange() {
        interface?.register(forTurnoutChange: { [weak self] address, state, power in
            guard let layout = self?.layout else {
                return
            }

            DispatchQueue.main.async {
                if let turnout = layout.turnouts.find(address: address) {
                    BTLogger.debug("Turnout \(turnout.name) changed state \(state) for address \(address.actualAddress.toHex())")
                    turnout.setState(value: state, for: address.actualAddress)
                    BTLogger.debug(" > Turnout \(turnout.name) changed to state \(turnout.state)")
                    layout.didChange()
                } else {
                    BTLogger.error("Unknown turnout for address \(address.actualAddress.toHex())")
                }
            }
        })
    }
    
}
