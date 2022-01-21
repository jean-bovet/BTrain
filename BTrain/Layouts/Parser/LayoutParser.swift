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

// n: = Route number at the beginning of the string
// {  = station block
// {{ = reserved station block
// {r0{ = station block with explicit reservation train identifier
// [  = free track
// [[ = reserved free track
// [r2[ = free track with explicit reservation route identifier
// {b0, {{b0, [b0, [[b0 = block identifier
// !{ = `!` indicates that a block is reversed, meaning the route enters the block from the reverse natural direction.
// ≏  = feedback sensor
// ≡  = feedback sensor (activated)
// <t0{sl}(0,1),s> = turnout <t<id>{type}(fromSocket,toSocket),state> where:
//    - type is optional and will default to straight right. Type can be "sl", "sr", "tw", "ds" and "ds2"
//    - state can be: s, l, r, s01, s23, b21, b03
// 🚂 = train
// 🛑🚂 = train stopped
// 🟨🚂 = train braking
// For example:
// { ≏ ≏ } [r0[ ≏ ≏ 🚂 ]] [[ ≏ ≏ ]] [ ≏ ≏ ] {b0 ≏ ≏ }
// { ≏ ≏ } <t0:0:1:0> [[r0b0 ≏ ≏ 🚂 ]] <t1:0:1:0> [[ ≏ ≏ ]] [ ≏ ≏ ] <t0:1:0:1> !{b0 ≏ ≏ }
final class LayoutParser {
            
    let routeStrings: [String]
    
    let layout = Layout()
    let routes = [Route]()

    convenience init(routeString: String) {
        self.init([routeString])
    }
    
    init(_ routeStrings: [String]) {
        self.routeStrings = routeStrings
    }
    
    func parse() {
        
        var blocks = Set<Block>()
        var trains = Set<Train>()
        var feedbacks = Set<Feedback>()
        
        for (index, rs) in routeStrings.enumerated() {
            let parser = LayoutRouteParser(ls: rs, id: String(index), layout: layout)
            parser.parse()

            for train in parser.trains {
                if let existingTrain = trains.first(where: {$0.id == train.id}) {
                    // Ensure that if the train is already defined, its attributes
                    // match the one re-defined later. This is to ensure the ASCII
                    // representation of a route is consistent across routes.
                    assert(train.speed == existingTrain.speed, "Mismatching speed definition for train \(train) and route \(String(describing: train.routeId))")
                    assert(train.position == existingTrain.position, "Mismatching position definition for train \(train) and route \(String(describing: train.routeId))")
                }
                trains.insert(train)
            }
            
            let route = parser.route!
            layout.routes.append(route)
            for block in parser.blocks {
                blocks.insert(block)
            }
            
            for feedback in parser.feedbacks {
                feedbacks.insert(feedback)
            }
        }

        layout.trains = trains.map { $0 }.sorted()
        layout.feedbacks = feedbacks.map { $0 }.sorted()
        layout.add(blocks.map { $0 }.sorted().reversed())
    }
    
}
