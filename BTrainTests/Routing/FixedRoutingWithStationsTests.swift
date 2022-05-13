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

/// These tests focus on the handling and management of a station, which is a group of blocks.
class FixedRoutingWithStationsTests: XCTestCase {

    /// This test simulates a train traveling from one station (s) to another (n).
    func testStationToStation() throws {
        let layout = LayoutLoopWithStations().newLayout()

        let p = FixedRoutingTests.Package(layout: layout)
        try p.prepare(routeID: "r1", trainID: "16390", fromBlockId: "1" /*s1*/, position: .end)
        
        try p.assert("r1: {r16390{s1 ≏ 💺16390 ≏ 🔴🚂16390 }} <ts2(1,0),s> <t1(0,1),s> <t2(0,1),s> [b1 ≏ ≏ ] <t4(1,0)> <tn1(0,1)> {n1 ≏ ≏ }")

        try p.start()

        XCTAssertTrue(p.train.managedScheduling)

        try p.assert("r1: {r16390{s1 ≏ 💺16390 ≏ 🟢🚂16390 }} <r16390<ts2{sl}(1,0),s>> <r16390<t1{sr}(0,1),s>> <r16390<t2{sr}(0,1),s>> [r16390[b1 ≏ ≏ ]] <r16390<t4{sl}(1,0),s>> <r16390<tn1{sr}(0,1),s>> {r16390{n1 ≏ ≏ }}")
        
        try p.assert("r1: {s1 ≏ ≏ } <ts2{sl}(1,0),s> <t1{sr}(0,1),s> <t2{sr}(0,1),s> [r16390[b1 💺16390 ≡ 🔵🚂16390 ≏ ]] <r16390<t4{sl}(1,0),s>> <r16390<tn1{sr}(0,1),s>> {r16390{n1 ≏ ≏ }}")

        try p.assert("r1: {s1 ≏ ≏ } <ts2{sl}(1,0),s> <t1{sr}(0,1),s> <t2{sr}(0,1),s> [r16390[b1 ≏ 💺16390 ≡ 🔵🚂16390 ]] <r16390<t4{sl}(1,0),s>> <r16390<tn1{sr}(0,1),s>> {r16390{n1 ≏ ≏ }}")

        try p.assert("r1: {s1 ≏ ≏ } <ts2{sl}(1,0),s> <t1{sr}(0,1),s> <t2{sr}(0,1),s> [b1 ≏ ≏ ] <t4{sl}(1,0),s> <tn1{sr}(0,1),s> {r16390{n1 💺16390 ≡ 🟡🚂16390 ≏ }}")

        try p.assert("r1: {s1 ≏ ≏ } <ts2{sl}(1,0),s> <t1{sr}(0,1),s> <t2{sr}(0,1),s> [b1 ≏ ≏ ] <t4{sl}(1,0),s> <tn1{sr}(0,1),s> {r16390{n1 ≏ 💺16390 ≡ 🔴🚂16390 }}")

        XCTAssertFalse(p.train.managedScheduling)
    }
        
    /// This test simulates a train traveling from one station (s) to another (n) and having another train reserving a block in the destination station (n) while the first train
    /// is already running to ensure the route for that train is updated to pick up the other free block of the station (n).
    func testStationToStationWithReservation() throws {
        let layout = LayoutLoopWithStations().newLayout()
        layout.trains[0].maxNumberOfLeadingReservedBlocks = 1
        
        let p = FixedRoutingTests.Package(layout: layout)
        try p.prepare(routeID: "r1", trainID: "16390", fromBlockId: "1" /*s1*/, position: .end)
        
        try p.assert("r1: {r16390{s1 ≏ 💺16390 ≏ 🔴🚂16390 }} <ts2(1,0),s> <t1(0,1),s> <t2(0,1),s> [b1 ≏ ≏ ] <t4(1,0)> <tn1(0,1)> {n1 ≏ ≏ }")

        try p.start()

        XCTAssertTrue(p.train.managedScheduling)

        try p.assert("r1: {r16390{s1 ≏ 💺16390 ≏ 🔵🚂16390 }} <r16390<ts2{sl}(1,0),s>> <r16390<t1{sr}(0,1),s>> <r16390<t2{sr}(0,1),s>> [r16390[b1 ≏ ≏ ]] <t4{sl}(1,0),s> <tn1{sr}(0,1),s> {n1 ≏ ≏ }")
        
        // Simulate a train reserving block "n1", which means that the train 16390 route will need to be updated to pick up the other free block in the station, "n2"
        let n1 = layout.block(named: "n1")
        n1.reserved = .init("foo", .next)

        try p.assert("r1: {s1 ≏ ≏ } <ts2{sl}(1,0),s> <t1{sr}(0,1),s> <t2{sr}(0,1),s> [r16390[b1 💺16390 ≡ 🔵🚂16390 ≏ ]] <r16390<t4{sl}(1,0),s>> <r16390<tn1{sr}(0,2),r>> {r16390{n2 ≏ ≏ }}")

        try p.assert("r1: {s1 ≏ ≏ } <ts2{sl}(1,0),s> <t1{sr}(0,1),s> <t2{sr}(0,1),s> [r16390[b1 ≏ 💺16390 ≡ 🔵🚂16390 ]] <r16390<t4{sl}(1,0),s>> <r16390<tn1{sr}(0,2),r>> {r16390{n2 ≏ ≏ }}")

        try p.assert("r1: {s1 ≏ ≏ } <ts2{sl}(1,0),s> <t1{sr}(0,1),s> <t2{sr}(0,1),s> [b1 ≏ ≏ ] <t4{sl}(1,0),s> <tn1{sr}(0,2),r> {r16390{n2 💺16390 ≡ 🟡🚂16390 ≏ }}")

        try p.assert("r1: {s1 ≏ ≏ } <ts2{sl}(1,0),s> <t1{sr}(0,1),s> <t2{sr}(0,1),s> [b1 ≏ ≏ ] <t4{sl}(1,0),s> <tn1{sr}(0,2),r> {r16390{n2 ≏ 💺16390 ≡ 🔴🚂16390 }}")

        XCTAssertFalse(p.train.managedScheduling)
    }

    func testMultipleTrains() throws {
        let layout = LayoutComplex().newLayout().removeTrains()
        
        let p = FixedRoutingTests.Package(layout: layout)
        try p.prepare(routeID: "r1", trainID: "16389", fromBlockId: "NE2", position: .end)
        
        try p.assert("r1: {r16389{NE2 ≏ 💺16389 ≏ 🔴🚂16389 }} <B.4{sl}(1,0),s> <A.1{sl}(2,0),s> <A.34{ds2}(3,2),b03> <A.2{sr}(2,0),r> [IL1 ≏ ≏ ] <H.1{sl}(1,0),s> <D.2{ds2}(0,1),s01> [IL2 ≏ ≏ ≏ ] <E.3{sl}(0,2),l> <E.1{sl}(2,0),l> [OL3 ≏ ≏ ] <F.3{sr}(0,1),s> <F.1{sr}(0,2),r> <E.4{sr}(0,1),s> {r16389{NE2 ≏ 💺16389 ≏ 🔴🚂16389 }}")
        
        try p.start()

        XCTAssertTrue(p.train.managedScheduling)
        
        try p.assert("r1: {r16389{NE2 ≏ 💺16389 ≏ 🔵🚂16389 }} <r16389<B.4{sl}(1,0),s>> <r16389<A.1{sl}(2,0),l>> <r16389<A.34{ds2}(3,2),s23>> <r16389<A.2{sr}(2,0),r>> [r16389[IL1 ≏ ≏ ]] <r16389<H.1{sl}(1,0),s>> <r16389<D.2{ds2}(0,1),s01>> [r16389[IL2 ≏ ≏ ≏ ]] <E.3{sl}(0,2),l> <E.1{sl}(2,0),l> [OL3 ≏ ≏ ] <F.3{sr}(0,1),s> <F.1{sr}(0,2),r> <E.4{sr}(0,1),s> {r16389{NE2 ≏ 💺16389 ≏ 🔵🚂16389 }}")
    }
}
