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

protocol LayoutCreating {
    static var id: Identifier<Layout> { get }
    var name: String { get }
    func newLayout() -> Layout
}

final class LayoutFactory {

    static let DefaultMaximumSpeed: TrainSpeed.UnitKph = {
        TrainSpeed.UnitKph(SettingsKeys.integer(forKey: SettingsKeys.maximumSpeed, 120))
    }()
    static let DefaultLimitedSpeed: TrainSpeed.UnitKph = {
        TrainSpeed.UnitKph(SettingsKeys.integer(forKey: SettingsKeys.limitedSpeed, 71))
    }()
    static let DefaultBrakingSpeed: TrainSpeed.UnitKph = {
        TrainSpeed.UnitKph(SettingsKeys.integer(forKey: SettingsKeys.brakingSpeed, 30))
    }()

    static let GlobalLayouts: [LayoutCreating] = [
        LayoutBlankCreator(),
        LayoutPointToPoint(),
        LayoutFigure8(),
        LayoutLoop1(),
        LayoutLoop2(),
        LayoutComplexLoop(),
        LayoutLoopWithStation(),
        LayoutComplex()
    ]

    static let GlobalLayoutIDs: [Identifier<Layout>] = {
        return GlobalLayouts.map { type(of: $0).id }
    }()
    
    static func globalLayoutName(_ id: Identifier<Layout>) -> String {
        return GlobalLayouts.filter { type(of: $0).id == id }.first!.name
    }
    
    static func createLayout(_ id: Identifier<Layout>) -> Layout {
        return GlobalLayouts.filter { type(of: $0).id == id }.first!.newLayout()
    }

    static func layoutFrom(_ routeString: String) -> Layout {
        return layoutFrom([routeString])
    }
    
    static func layoutFrom(_ routeStrings: [String]) -> Layout {
        let parser = LayoutParser(routeStrings)
        parser.parse()
        return parser.layout
    }
    
    static func layoutFromBundle(named: String) -> Layout {
        let file = Bundle.main.url(forResource: named, withExtension: "btrain", subdirectory: "Layouts")!
        let fw = try! FileWrapper(url: file)
        return try! fw.layout()
    }

}
