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

import XCTest
@testable import BTrain

extension XCTestCase {
    
    func connectToSimulator(doc: LayoutDocument, enable: Bool = true) {
        let c = expectation(description: "connect")
        doc.simulator.turnoutSpeed = 0
        doc.connectToSimulator(enable: false) { error in
            c.fulfill()
        }
        
        waitForExpectations(timeout: 0.5, handler: nil)

        if enable {
            let e = expectation(description: "enable")
            doc.enable() {
                e.fulfill()
            }
            
            waitForExpectations(timeout: 0.5, handler: nil)
        }
    }

    func disconnectFromSimulator(doc: LayoutDocument, disable: Bool = true) {
        if disable {
            let d = expectation(description: "disable")
            doc.disable() {
                d.fulfill()
            }
            
            waitForExpectations(timeout: 0.5, handler: nil)
        }

        let e = expectation(description: "disconnect")
        doc.disconnect() {
            e.fulfill()
        }
        
        waitForExpectations(timeout: 0.5, handler: nil)
    }

}
