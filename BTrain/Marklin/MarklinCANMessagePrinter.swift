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

struct MarklinCANMessagePrinter {

    static func debugDescription(msg: MarklinCANMessage) -> String? {
        if let description = MarklinCANMessagePrinter.description(message: msg) {
            return "\(description), data: \(msg.data as NSData)"
        } else {
            return nil
        }
    }
    
    static func description(message: MarklinCANMessage) -> String? {
        let cmd = Command.from(message: message)
        switch(cmd) {
        case .go(priority: _, descriptor: let descriptor):
            return descriptor?.description
            
        case .stop(priority: _, descriptor: let descriptor):
            return descriptor?.description

        case .emergencyStop(address: _, decoderType: _, priority: _, descriptor: let descriptor):
            return descriptor?.description

        case .speed(address: _, decoderType: _, value: _, priority: _, descriptor: let descriptor):
            return descriptor?.description

        case .direction(address: _, decoderType: _, direction: _, priority: _, descriptor: let descriptor):
            return descriptor?.description

        case .queryDirection(address: _, decoderType: _, priority: _, descriptor: let descriptor):
            return descriptor?.description

        case .turnout(address: _, state: _, power: _, priority: _, descriptor: let descriptor):
            return descriptor?.description

        case .feedback(deviceID: _, contactID: _, oldValue: _, newValue: _, time: _, priority: _, descriptor: let descriptor):
            return descriptor?.description

        case .locomotives(priority: _, descriptor: let descriptor):
            return descriptor?.description

        case .unknown(command: _, priority: _, descriptor: let descriptor):
            let mc = MarklinCommand.from(message: message)
            switch(mc) {
            case .configDataStream(length: _, data: _, descriptor: let descriptor):
                return descriptor?.description
            case .queryDirectionResponse(address: _, decoderType: _, direction: _, descriptor: let descriptor):
                return descriptor?.description

            case .none:
                if SettingsKeys.bool(forKey: SettingsKeys.logUnknownMessages) {
                    return descriptor?.description
                } else {
                    return nil
                }
            }
        }
    }
    
}
