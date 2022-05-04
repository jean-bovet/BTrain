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

class ManualRoutingWithStationsTests: XCTestCase {

    func testLoopWithStations1() throws {
        let layout = LayoutLoopWithStations().newLayout()

        let p = ManualRoutingTests.Package(layout: layout)
        try p.prepare(routeID: "C844F586-908C-452B-BEE4-9FC12EB60640", trainID: "16390", fromBlockId: "1" /*s1*/, position: .end)
        
        try p.assert("C844F586-908C-452B-BEE4-9FC12EB60640: {r16390{s1 ≏ 💺16390 ≏ 🔴🚂16390 }} <ts2(1,0),s> <t1(0,1),s> <t2(0,1),s> [b1 ≏ ≏ ] <t4(1,0)> <tn1(0,1)> {n1 ≏ ≏ }")

        try p.start()

        XCTAssertTrue(p.train.managedScheduling)

        try p.assert("C844F586-908C-452B-BEE4-9FC12EB60640: {r16390{s1 ≏ 💺16390 ≏ 🟢🚂16390 }} <r16390<ts2{sl}(1,0),s>> <r16390<t1{sr}(0,1),s>> <r16390<t2{sr}(0,1),s>> [r16390[b1 ≏ ≏ ]] <r16390<t4{sl}(1,0),s>> <r16390<tn1{sr}(0,1),s>> {r16390{n1 ≏ ≏ }}")
        
        try p.assert("C844F586-908C-452B-BEE4-9FC12EB60640: {s1 ≏ ≏ } <ts2{sl}(1,0),s> <t1{sr}(0,1),s> <t2{sr}(0,1),s> [r16390[b1 💺16390 ≡ 🔵🚂16390 ≏ ]] <r16390<t4{sl}(1,0),s>> <r16390<tn1{sr}(0,1),s>> {r16390{n1 ≏ ≏ }}")

        try p.assert("C844F586-908C-452B-BEE4-9FC12EB60640: {s1 ≏ ≏ } <ts2{sl}(1,0),s> <t1{sr}(0,1),s> <t2{sr}(0,1),s> [r16390[b1 ≏ 💺16390 ≡ 🔵🚂16390 ]] <r16390<t4{sl}(1,0),s>> <r16390<tn1{sr}(0,1),s>> {r16390{n1 ≏ ≏ }}")

        try p.assert("C844F586-908C-452B-BEE4-9FC12EB60640: {s1 ≏ ≏ } <ts2{sl}(1,0),s> <t1{sr}(0,1),s> <t2{sr}(0,1),s> [b1 ≏ ≏ ] <t4{sl}(1,0),s> <tn1{sr}(0,1),s> {r16390{n1 💺16390 ≡ 🟡🚂16390 ≏ }}")

        try p.assert("C844F586-908C-452B-BEE4-9FC12EB60640: {s1 ≏ ≏ } <ts2{sl}(1,0),s> <t1{sr}(0,1),s> <t2{sr}(0,1),s> [b1 ≏ ≏ ] <t4{sl}(1,0),s> <tn1{sr}(0,1),s> {r16390{n1 ≏ 💺16390 ≡ 🔴🚂16390 }}")

        XCTAssertFalse(p.train.managedScheduling)
    }
    
    // TODO: test with a destination station whose reserved block change as the train move (ie after the train start, another one comes and blocks the initial blocks of the station so the route must be updated again).
}
