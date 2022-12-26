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

@testable import BTrain
import XCTest

final class TrainFunctionsControllerTests: XCTestCase {
    let mock = MockCommandInterface()

    var loc: Locomotive!
    var train: Train!
    var controller: TrainFunctionsController!

    override func setUp() {
        let catalog = LocomotiveFunctionsCatalog(interface: mock)
        controller = TrainFunctionsController(catalog: catalog, interface: mock)
        loc = Locomotive()
        loc.functions.definitions = [.init(nr: 1, state: 0, type: 10), .init(nr: 3, state: 0, type: 7), .init(nr: 7, state: 0, type: 10)]
        train = Train()
        train.locomotive = loc
    }

    func testGenericFunction() {
        // Type 10 is present twice in the locomotive functions but because we only use the type, only the first occurrence found for nr==1 is used.
        assert(function: RouteItemFunction(type: 10), index: 1)
        assert(function: RouteItemFunction(type: 7), index: 3)
    }

    func testLocomotiveSpecificFunction() {
        assert(function: RouteItemFunction(locFunction: loc.functions.definitions[0], type: 0), index: 1)
        assert(function: RouteItemFunction(locFunction: loc.functions.definitions[1], type: 0), index: 3)
        assert(function: RouteItemFunction(locFunction: loc.functions.definitions[2], type: 0), index: 7)
    }

    func assert(function: RouteItemFunction, index: UInt8) {
        controller.execute(functions: .init(id: "", functions: [function]), train: train)
        wait(for: {
            mock.triggeredFunctions.count == 1
        }, timeout: 0.1)
        XCTAssertEqual(mock.triggeredFunctions[0].index, index)
        XCTAssertEqual(mock.triggeredFunctions[0].address, loc.address)
        XCTAssertEqual(mock.triggeredFunctions[0].value, 1)
        mock.triggeredFunctions.removeAll()
    }
}
