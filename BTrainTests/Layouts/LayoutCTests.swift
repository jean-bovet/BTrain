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

class LayoutCTests: RootLayoutTests {
    
    override var layoutID: Identifier<Layout>? {
        return LayoutCCreator.id
    }
    
    func testMoveRouteLoop() throws {
        try layout.prepare(routeID: "r1", trainID: "1")
        try layout.prepare(routeID: "r3", trainID: "2")
        
        assert2("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] {r2{b3 🛑🚂2 ≏ ≏ }} <t1> [b4 ≏ ≏] {r1{b1 🛑🚂1 ≏ ≏ }}",
                "r3: {r2{b3 🛑🚂2 ≏ ≏ }} <t1(0,2)> [b5 ≏ ≏ ] <t0(2,0)> !{r1{b1 🛑🚂1 ≏ ≏ }}")

        try layoutController.start(routeID: "r1", trainID: "1")

        assert2("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] {r2{b3 🛑🚂2 ≏ ≏ }} <t1> [b4 ≏ ≏] {r1{b1 🚂1 ≏ ≏ }}",
                "r3: {r2{b3 🛑🚂2 ≏ ≏ }} <t1(0,2)> [b5 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 🚂1 ≏ ≏ }}")
        
        try layoutController.start(routeID: "r3", trainID: "2")

        assert2("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] {r2{b3 🚂2 ≏ ≏ }} <r2<t1,r>> [b4 ≏ ≏] {r1{b1 🚂1 ≏ ≏ }}",
                "r3: {r2{b3 🚂2 ≏ ≏ }} <r2<t1(0,2),r>> [r2[b5 ≏ ≏ ]] <r1<t0(2,0)>> !{r1{b1 🚂1 ≏ ≏ }}")

        assert2("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] {r2{b3 ≡ 🚂2 ≏ }} <r2<t1,r>> [b4 ≏ ≏] {r1{b1 🚂1 ≏ ≏ }}",
                "r3: {r2{b3 ≡ 🚂2 ≏ }} <r2<t1(0,2),r>> [r2[b5 ≏ ≏ ]] <r1<t0(2,0)>> !{r1{b1 🚂1 ≏ ≏ }}")

        assert2("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] {r2{b3 ≡ ≡ 🚂2 }} <r2<t1,r>> [b4 ≏ ≏] {r1{b1 🚂1 ≏ ≏ }}",
                "r3: {r2{b3 ≡ ≡ 🚂2 }} <r2<t1(0,2),r>> [r2[b5 ≏ ≏ ]] <r1<t0(2,0)>> !{r1{b1 🚂1 ≏ ≏ }}")

        assert2("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] {b3 ≏ ≏ } <t1,r> [b4 ≏ ≏] {r1{b1 🚂1 ≏ ≏ }}",
                "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≡ 🚂2 ≏ ]] <r1<t0(2,0)>> !{r1{b1 🚂1 ≏ ≏ }}")

        // Train 2 stops because block b1 is still in use by train 1.
        assert2("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] {b3 ≏ ≏ } <t1,r> [b4 ≏ ≏] {r1{b1 🚂1 ≏ ≏ }}",
                "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≡ ≡ 🛑🚂2 ]] <r1<t0(2,0)>> !{r1{b1 🚂1 ≏ ≏ }}")

        assert2("r1: {r1{b1 ≡ 🚂1 ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] {b3 ≏ ≏ } <t1,r> [b4 ≏ ≏] {r1{b1 ≡ 🚂1 ≏ }}",
                "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≏ ≏ 🛑🚂2 ]] <r1<t0(2,0)>> !{r1{b1 ≡ 🚂1 ≏ }}")

        assert2("r1: {r1{b1 ≡ ≡ 🚂1 }} <r1<t0>> [r1[b2 ≏ ≏ ]] {b3 ≏ ≏ } <t1,r> [b4 ≏ ≏] {r1{b1 ≡ ≡ 🚂1 }}",
                "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≏ ≏ 🛑🚂2 ]] <r1<t0(2,0)>> !{r1{b1 ≡ ≡ 🚂1 }}")

        // Train 2 starts again because block 1 is now free (train 1 has moved to block 2).
        assert2("r1: {r2{b1 ≏ ≏ }} <r2<t0,r>> [r1[b2 ≡ 🚂1 ≏ ]] {r1{b3 ≏ ≏ }} <t1,r> [b4 ≏ ≏] {r2{b1 ≏ ≏ }}",
                "r3: {r1{b3 ≏ ≏ }} <t1(0,2),r> [r2[b5 ≏ ≏ 🚂2 ]] <r2<t0(2,0),r>> !{r2{b1 ≏ ≏ }}")

        assert2("r1: {r2{b1 ≏ ≏ }} <r2<t0,r>> [r1[b2 ≡ ≡ 🚂1 ]] {r1{b3 ≏ ≏ }} <t1,r> [b4 ≏ ≏] {r2{b1 ≏ ≏ }}",
                "r3: {r1{b3 ≏ ≏ }} <t1(0,2),r> [r2[b5 ≏ ≏ 🚂2 ]] <r2<t0(2,0),r>> !{r2{b1 ≏ ≏ }}")
        
        assert2("r1: {r2{b1 ≏ 🚂2 ≡ }} <t0,r> [r1[b2 ≏ ≏ 🚂1 ]] {r1{b3 ≏ ≏ }} <t1,r> [b4 ≏ ≏] {r2{b1 ≏ 🚂2 ≡ }}",
                "r3: {r1{b3 ≏ ≏ }} <t1(0,2),r> [b5 ≏ ≏ ] <t0(2,0),r> !{r2{b1 ≏ 🚂2 ≡ }}")

        // Train 2 stops because it has reached the end of the last block of its route (b1).
        assert2("r1: {r2{b1 🛑🚂2 ≡ ≡ }} <t0,r> [b2 ≏ ≏ ] {r1{b3 ≡ 🚂1 ≏ }} <r1<t1>> [r1[b4 ≏ ≏]] {r2{b1 🛑🚂2 ≡ ≡ }}",
                "r3: {r1{b3 ≡ 🚂1 ≏ }} <r1<t1(0,2)>> [b5 ≏ ≏ ] <t0(2,0),r> !{r2{b1 🛑🚂2 ≡ ≡ }}")

        assert2("r1: {r2{b1 🛑🚂2 ≏ ≏ }} <t0,r> [b2 ≏ ≏ ] {r1{b3 ≡ ≡ 🚂1 }} <r1<t1>> [r1[b4 ≏ ≏]] {r2{b1 🛑🚂2 ≏ ≏ }}",
                "r3: {r1{b3 ≡ ≡ 🚂1 }} <r1<t1(0,2)>> [b5 ≏ ≏ ] <t0(2,0),r> !{r2{b1 🛑🚂2 ≏ ≏ }}")

        assert2("r1: {r2{b1 🛑🚂2 ≏ ≏ }} <t0,r> [b2 ≏ ≏ ] {b3 ≏ ≏ } <t1> [r1[b4 ≡ 🚂1 ≏]] {r2{b1 🛑🚂2 ≏ ≏ }}",
                "r3: {b3 ≏ ≏ } <t1(0,2)> [b5 ≏ ≏ ] <t0(2,0),r> !{r2{b1 🛑🚂2 ≏ ≏ }}")

        // Train 1 stops again because there is a train in the next block b1 (train 2)
        assert2("r1: {r2{b1 🛑🚂2 ≏ ≏ }} <t0,r> [b2 ≏ ≏ ] {b3 ≏ ≏ } <t1> [r1[b4 ≡ ≡ 🛑🚂1 ]] {r2{b1 🛑🚂2 ≏ ≏ }}",
                "r3: {b3 ≏ ≏ } <t1(0,2)> [b5 ≏ ≏ ] <t0(2,0),r> !{r2{b1 🛑🚂2 ≏ ≏ }}")

        // Let's remove train 2 artificially to allow train 1 to stop at the station b1
        try layout.free(trainID: Identifier<Train>(uuid: "2"), removeFromLayout: true)
        assert2("r1: {r1{b1 ≏ ≏ }} <t0,r> [b2 ≏ ≏ ] {b3 ≏ ≏ } <t1> [r1[b4 ≡ ≡ 🚂1 ]] {r1{b1 ≏ ≏ }}",
                "r3: {b3 ≏ ≏ } <t1(0,2)> [b5 ≏ ≏ ] <t0(2,0),r> !{r1{b1 ≏ ≏ }}")

        assert2("r1: {r1{b1 ≡ 🚂1 ≏ }} <t0,r> [b2 ≏ ≏ ] {b3 ≏ ≏ } <t1> [b4 ≏ ≏ ] {r1{b1 ≡ 🚂1 ≏ }}",
                "r3: {b3 ≏ ≏ } <t1(0,2)> [b5 ≏ ≏ ] <t0(2,0),r> !{r1{b1 ≡ 🚂1 ≏ }}")
        
        // Train 1 finally stops at the station b1 which is its final block of the route
        assert2("r1: {r1{b1 ≡ ≡ 🛑🚂1 }} <t0,r> [b2 ≏ ≏ ] {b3 ≏ ≏ } <t1> [b4 ≏ ≏ ] {r1{b1 ≡ ≡ 🛑🚂1 }}",
                "r3: {b3 ≏ ≏ } <t1(0,2)> [b5 ≏ ≏ ] <t0(2,0),r> !{r1{b1 ≡ ≡ 🛑🚂1 }}")
    }
 
    func testNextBlockFeedbackHandling() throws {
        try layout.prepare(routeID: "r1", trainID: "1")
        try layout.prepare(routeID: "r3", trainID: "2")
        
        layout.strictRouteFeedbackStrategy = false
        
        assert2("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] {r2{b3 🛑🚂2 ≏ ≏ }} <t1> [b4 ≏ ≏] {r1{b1 🛑🚂1 ≏ ≏ }}",
                "r3: {r2{b3 🛑🚂2 ≏ ≏ }} <t1(0,2)> [b5 ≏ ≏ ] <t0(2,0)> !{r1{b1 🛑🚂1 ≏ ≏ }}")

        try layoutController.start(routeID: "r3", trainID: "2")

        assert2("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] {r2{b3 🚂2 ≏ ≏ }} <r2<t1,r>> [b4 ≏ ≏] {r1{b1 🛑🚂1 ≏ ≏ }}",
                "r3: {r2{b3 🚂2 ≏ ≏ }} <r2<t1(0,2),r>> [r2[b5 ≏ ≏ ]] <t0(2,0)> !{r1{b1 🛑🚂1 ≏ ≏ }}")
        
        assert2("r1: {r1{b1 🛑🚂1 ≏ ≏ }} <t0> [b2 ≏ ≏ ] {b3 ≏ ≏ } <t1,r> [b4 ≏ ≏] {r1{b1 🛑🚂1 ≏ ≏ }}",
                "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≡ 🚂2 ≏ ]] <t0(2,0)> !{r1{b1 🛑🚂1 ≏ ≏ }}")
        
        try layoutController.start(routeID: "r1", trainID: "1")

        assert2("r1: {r1{b1 🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] {b3 ≏ ≏ } <t1,r> [b4 ≏ ≏] {r1{b1 🚂1 ≏ ≏ }}",
                "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≏ 🚂2 ≏ ]] <r1<t0(2,0)>> !{r1{b1 🚂1 ≏ ≏ }}")

        assert2("r1: {r1{b1 ≡ 🚂1 ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] {b3 ≏ ≏ } <t1,r> [b4 ≏ ≏] {r1{b1 ≡ 🚂1 ≏ }}",
                "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≏ 🚂2 ≏ ]] <r1<t0(2,0)>> !{r1{b1 ≡ 🚂1 ≏ }}")

        // Note: the last feedback of block b1 is activated which moves train 1 within b1. However, this feedback
        // is also used to move train 2 to block b1 but in this situation it should be ignored for train 2 because
        // block b1 is not free.
        assert2("r1: {r1{b1 ≏ ≡ 🚂1 }} <r1<t0>> [r1[b2 ≏ ≏ ]] {b3 ≏ ≏ } <t1,r> [b4 ≏ ≏] {r1{b1 ≏ ≡ 🚂1 }}",
                "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≏ 🚂2 ≏ ]] <r1<t0(2,0)>> !{r1{b1 ≏ ≡ 🚂1 }}")

        assert2("r1: {r1{b1 ≏ ≏ 🚂1 }} <r1<t0>> [r1[b2 ≏ ≏ ]] {b3 ≏ ≏ } <t1,r> [b4 ≏ ≏] {r1{b1 ≏ ≏ 🚂1 }}",
                "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≏ 🚂2 ≏ ]] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ 🚂1 }}")

        // Train 1 moves to b2
        assert2("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≡ 🚂1 ≏ ]] {r1{b3 ≏ ≏ }} <t1,r> [b4 ≏ ≏] {b1 ≏ ≏ }",
                "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≏ 🚂2 ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")

        // Train 2 moves to the end of block b5
        assert2("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≡ 🚂1 ≏ ]] {r1{b3 ≏ ≏ }} <t1,r> [b4 ≏ ≏] {b1 ≏ ≏ }",
                "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≏ ≡ 🛑🚂2 ]] <t0(2,0)> !{b1 ≏ ≏ }")

        // Now train 2 is starting again after reserving block b1 for itself
        assert2("r1: {r2{b1 ≏ ≏ }} <r2<t0,r>> [r1[b2 ≏ 🚂1 ≏ ]] {r1{b3 ≏ ≏ }} <t1,r> [b4 ≏ ≏] {r2{b1 ≏ ≏ }}",
                "r3: {b3 ≏ ≏ } <t1(0,2),r> [r2[b5 ≏ ≏ 🚂2 ]] <r2<t0(2,0),r>> !{r2{b1 ≏ ≏ }}")

        // Train 2 moves to b1 (entering in the previous direction!)
        assert2("r1: {r2{b1 ≏ 🚂2 ≡ }} <t0,r> [r1[b2 ≏ 🚂1 ≏ ]] {r1{b3 ≏ ≏ }} <t1,r> [b4 ≏ ≏] {r2{b1 ≏ 🚂2 ≡ }}",
                "r3: {b3 ≏ ≏ } <t1(0,2),r> [b5 ≏ ≏ ] <t0(2,0),r> !{r2{b1 ≏ 🚂2 ≡ }}")
    }
}
