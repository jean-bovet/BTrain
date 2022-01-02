// Copyright 2021 Jean Bovet
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
            
    var darkMode = false
    var showBlockName = false
    var showTurnoutName = false
    
    var fontSize: CGFloat = 12.0
    
    var trackWidth: CGFloat {
        return 4
    }

    var selectedTrackWidth: CGFloat {
        return 8
    }

    var color: CGColor {
        NSColor.textColor.cgColor
    }

    var reservedColor: CGColor {
        NSColor.red.cgColor
    }

    var backgroundStationBlock: CGColor {
        if darkMode {
            return NSColor.darkGray.cgColor
        } else {
            return NSColor.lightGray.cgColor
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

    func trainColor(_ speed: UInt16) -> CGColor {
        if speed == 0 {
            return NSColor.systemRed.cgColor
        } else {
            return NSColor.systemGreen.cgColor
        }
    }
}
