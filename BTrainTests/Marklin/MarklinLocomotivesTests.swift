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

final class MarklinLocomotivesTests: XCTestCase {
    var server: URL {
        MarklinCS3Server.cs3ServerDirectory
    }

    func testCS3FetchLocomotives() async throws {
        let cs3 = MarklinCS3()
        let locks = try await cs3.fetchLoks(server: server)
        XCTAssertEqual(locks.count, 18)

        let l1 = locks[0]
        XCTAssertEqual(l1.name, "193 524 SBB")
        XCTAssertEqual(l1.address, 14)
        XCTAssertEqual(l1.decoderType, .MFX)
        XCTAssertEqual(l1.icon, "/usr/local/cs3/lokicons/SBB 193 524-6 Cargo")
        XCTAssertEqual(l1.funktionen.count, 32)
        XCTAssertEqual(l1.funktionen[0].typ2, 1)

        let icon = try await cs3.fetchLokIcon(server: server, lok: l1)
        XCTAssertNotNil(icon)
    }

    func testFetchLocomotives() throws {
        let fetcher = MarklinFetchLocomotives()

        let expectation = expectation(description: "fetch")
        var locs: [CommandLocomotive]?
        fetcher.fetchLocomotives(server: server) { result in
            if case let .success(locomotives) = result {
                locs = locomotives
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0)

        guard let locs = locs else {
            XCTFail("Locs must be defined")
            return
        }

        XCTAssertEqual(locs.count, 18)

        let l1 = locs[0]
        XCTAssertEqual(l1.name, "193 524 SBB")
        XCTAssertEqual(l1.address, 14)
        XCTAssertEqual(l1.decoderType, .MFX)
        XCTAssertNotNil(l1.icon)
    }
}
