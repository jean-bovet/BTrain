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
// 􀼮 = train
// 􀼯 = wagon (used to indicate occupation of the train in the various parts of the block (only when train and block length are defined)
// 🔴􀼮 = train stopped
// 🟡􀼮 = train braking
// 🟠􀼮 = train stopping
// 🟠􀼮 = train stopping
// 🟢􀼮 = train running at full speed
// 🔵􀼮 = train running at limited speed
// For example:
// { ≏ ≏ } [r0[ ≏ ≏ 🟢􀼮 ]] [[ ≏ ≏ ]] [ ≏ ≏ ] {b0 ≏ ≏ }
// { ≏ ≏ } <t0:0:1:0> [[r0b0 ≏ ≏ 🟢􀼮 ]] <t1:0:1:0> [[ ≏ ≏ ]] [ ≏ ≏ ] <t0:1:0:1> !{b0 ≏ ≏ }
final class LayoutParser {
    let routeStrings: [String]
    let resolver: LayoutParserResolver
    
    final class ParsedLayout {
        var blocks = Set<Block>()
        var turnouts = Set<Turnout>()
        var trains = Set<Train>()
        var locs = Set<Locomotive>()
        var feedbacks = Set<Feedback>()
        var transitions = Set<Transition>()
        var routes = [Identifier<Route>: LayoutRouteParser.ParsedRoute]()

        func link(from: Socket, to: Socket) {
            transitions.insert(Transition(id: Identifier<Transition>(uuid: "\(transitions.count)"), a: from, b: to))
        }
    }

    var parsedLayout = ParsedLayout()

    convenience init(routeString: String, resolver: LayoutParserResolver) {
        self.init([routeString], resolver: resolver)
    }

    init(_ routeStrings: [String], resolver: LayoutParserResolver) {
        self.routeStrings = routeStrings
        self.resolver = resolver
    }

    func parse() throws {
        for (index, rs) in routeStrings.enumerated() {
            let parser = LayoutRouteParser(ls: rs, id: String(index), layout: parsedLayout, resolver: resolver)
            try parser.parse()
            parsedLayout.routes[parser.route.routeId] = parser.route
        }
    }
}

extension LayoutFactory {
    static func layoutFrom(_ routeString: String, resolver: LayoutParserResolver) throws -> LayoutParser.ParsedLayout {
        try layoutFrom([routeString], resolver: resolver)
    }

    static func layoutFrom(_ routeStrings: [String], resolver: LayoutParserResolver) throws -> LayoutParser.ParsedLayout {
        let parser = LayoutParser(routeStrings, resolver: resolver)
        try parser.parse()
        return parser.parsedLayout
    }
}
