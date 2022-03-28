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

struct SettingsKeys {
    
    static let autoConnectSimulator = "autoConnectSimulator"
    static let autoEnableSimulator = "autoEnableSimulator"
    static let fontSize = "fontSize"

    static let maximumSpeed = "maximumSpeed"
    static let limitedSpeed = "limitedSpeed"
    static let brakingSpeed = "brakingSpeed"

    static let automaticRouteRandom = "automaticRouteRandom"
    static let detectUnexpectedFeedback = "detectUnexpectedFeedback"
    static let strictRouteFeedbackStrategy = "strictRouteFeedbackStrategy"

    static let debugMode = "debugMode"
    static let recordDiagnosticLogs = "recordDiagnosticLogs"
    static let logRoutingResolutionSteps = "logRoutingResolutionSteps"

    static func bool(forKey key: String) -> Bool {
        return UserDefaults.standard.bool(forKey: key)
    }
    
    static func integer(forKey key: String, _ defaultValue: Int) -> Int {
        if UserDefaults.standard.value(forKey: key) == nil {
            UserDefaults.standard.set(defaultValue, forKey: key)
        }
        return UserDefaults.standard.integer(forKey: key)
    }
}

