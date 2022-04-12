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
import AppKit

// https://nshipster.com/dark-mode/
final class ShapeContext {
            
    var simulator: Simulator?

    var trainIconManager: TrainIconManager?
    
    var darkMode = false
    var showBlockName = false
    var showStationName = false
    var showTurnoutName = false
    var showTrainIcon = true
    
    var fontSize: CGFloat = 12.0
    
    var expectedFeedbackIds: Set<Identifier<Feedback>>?

    var trackWidth: CGFloat {
        return 4
    }

    var selectedTrackWidth: CGFloat {
        return 8
    }

    var color: CGColor {
        NSColor.textColor.cgColor
    }

    var reservedOnlyColor: CGColor {
        NSColor.orange.cgColor
    }

    var occupiedColor: CGColor {
        NSColor.red.cgColor
    }

    var backgroundStationBlockColor: CGColor {
        if darkMode {
            return NSColor.darkGray.cgColor
        } else {
            return NSColor.lightGray.cgColor.copy(alpha: 0.5)!
        }
    }
    
    var backgroundLabelColor: CGColor {
        if darkMode {
            return NSColor.darkGray.cgColor
        } else {
            return NSColor.white.cgColor
        }
    }

    var borderLabelColor: CGColor {
        if darkMode {
            return NSColor.lightGray.cgColor
        } else {
            return NSColor.black.cgColor
        }
    }

    var dropTrainPathColor: CGColor {
        NSColor.selectedTextBackgroundColor.cgColor
    }

    var activeFeedbackColor: CGColor {
        NSColor.systemRed.cgColor
    }

    var inactiveFeedbackColor: CGColor {
        NSColor.systemGray.cgColor
    }

    var freeSocketColor: CGColor {
        NSColor.green.cgColor
    }

    var plugColor: CGColor {
        NSColor.red.cgColor
    }

    var rotationHandleColor: CGColor {
        NSColor.blue.cgColor
    }

    init(simulator: Simulator? = nil, trainIconManager: TrainIconManager? = nil) {
        self.simulator = simulator
        self.trainIconManager = trainIconManager
    }
    
    
    /// Returns the color of the path given the reservation status and the presence of a train
    /// - Parameters:
    ///   - reserved: true if the element is reserved
    ///   - train: true if the element contains a train
    /// - Returns: The color of the path
    func pathColor(_ reserved: Bool, train: Bool) -> CGColor {
        if reserved {
            if train {
                return occupiedColor
            } else {
                return reservedOnlyColor
            }
        } else {
            return color
        }
    }
    
    func trainColor(_ train: Train) -> CGColor {
        switch(train.state) {
        case .running:
            return NSColor.systemGreen.cgColor
        case .braking:
            return NSColor.systemYellow.cgColor
        case .stopping:
            return NSColor.systemOrange.cgColor
        case .stopped:
            return NSColor.systemRed.cgColor
        }
    }
}
