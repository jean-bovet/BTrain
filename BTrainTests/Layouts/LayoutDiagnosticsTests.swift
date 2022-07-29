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

class LayoutDiagnosticsTests: XCTestCase {

    func testValidateLayout() throws {
        let layout = LayoutComplexLoop().newLayout()
        let diag = LayoutDiagnostic(layout: layout)
        let errors = try diag.check(.skipLengths)
        XCTAssertEqual(errors.count, 0)
    }

    func testTurnoutMissingTransition() throws {
        let layout =  LayoutIncomplete().newLayout()
        let diag = LayoutDiagnostic(layout: layout)
        let errors = try diag.check(.skipLengths)
        XCTAssertEqual(errors.count, 8)
        
        let turnout = layout.turnouts[0]
        XCTAssertEqual(errors[1], LayoutDiagnostic.DiagnosticError.turnoutMissingTransition(turnout: turnout, socket: turnout.socketName(turnout.socket0.socketId!)))
    }
    
    func testTurnoutDuplicateAddress() throws {
        let layout = LayoutComplexLoop().newLayout()
        let diag = LayoutDiagnostic(layout: layout)
        var errors = [LayoutDiagnostic.DiagnosticError]()
        diag.checkForDuplicateTurnouts(&errors)
        XCTAssertEqual(errors.count, 0)
        
        let t0 = layout.turnouts[0]
        let t1 = layout.turnouts[1]

        t0.address = t1.address
        diag.checkForDuplicateTurnouts(&errors)
        XCTAssertEqual(errors.count, 1)
        
        t0.category = .threeWay
        t0.address2 = t1.address2
        diag.checkForDuplicateTurnouts(&errors)
        XCTAssertEqual(errors.count, 2)
    }

    func testTtrainDuplicateAddress() throws {
        let layout = LayoutComplexLoop().newLayout()
        let diag = LayoutDiagnostic(layout: layout)
        var errors = [LayoutDiagnostic.DiagnosticError]()
        diag.checkForDuplicateTrains(&errors)
        XCTAssertEqual(errors.count, 0)
        
        let t0 = layout.trains[0]
        let t1 = layout.trains[1]

        t0.address = t1.address
        diag.checkForDuplicateTrains(&errors)
        XCTAssertEqual(errors.count, 1)
    }

    func testValidateRoute() throws {
        let layout = LayoutLoopWithStations().newLayout()
        let diag = LayoutDiagnostic(layout: layout)
        var errors = [LayoutDiagnostic.DiagnosticError]()
        diag.checkRoutes(&errors)
        XCTAssertEqual(errors.count, 0)
    }

}
