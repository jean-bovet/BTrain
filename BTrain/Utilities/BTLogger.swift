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
import OSLog

/// Manages all the logging happening inside BTrain.
///
/// The underlying implementation uses the unified [OS logging system](https://developer.apple.com/documentation/os/logging).
final class BTLogger {
    
    /// Return a new network logger instance
    static private var newNetworkLogger: Logger {
        SettingsKeys.bool(forKey: SettingsKeys.logCategoryNetwork) ? Logger(subsystem: "ch.arizona-software.BTrain", category: "network") : Logger(OSLog.disabled)
    }
        
    /// The public network logger instance
    static var network = newNetworkLogger
        
    static let router = Logger(subsystem: "ch.arizona-software.BTrain", category: "router")
    
    /// Re-created the network logger using the latest settings
    static func updateNetworkLogger() {
        network = newNetworkLogger
    }
    
    static func error(_ msg: String) {
        NSLog("⛔️ \(msg)")
    }
    
    static func debug(_ msg: String) {
        NSLog("\(msg)")
    }
    
    static func warning(_ msg: String) {
        NSLog("⚠️ \(msg)")
    }

}
