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

extension Route {
    /// Find all the missing blocks from the ``partialSteps`` steps and assign the completed
    /// array of blocks to ``steps``.
    ///
    /// This method must be called each time the route definition changes (ie the user edit the route).
    ///
    /// - Parameters:
    ///   - layout: the layout to use
    ///   - train: the train to use
    func completePartialSteps(layout: Layout, train: Train) throws {
        steps = try complete(partialItems: partialSteps, layout: layout, train: train)
    }

    private func complete(partialItems: [RouteItem], layout: Layout, train: Train) throws -> [RouteItem] {
        let resolver = RouteResolver(layout: layout, train: train)
        guard var previousItem = partialItems.first else {
            return partialItems
        }

        var completeItems = [previousItem]

        // This loop will take each partial item and will resolve the missing items
        // in between each partial items.
        for nextItem in partialItems.dropFirst() {
            let result = try resolver.resolve(unresolvedPath: [previousItem, nextItem])
            switch result {
            case let .success(resolvedPaths):
                if let resolvedPath = resolvedPaths.randomElement() {
                    // The first and last of the resolved steps are the same as previousItem
                    // and nextItem, so we skip them because we need to keep the original
                    // previousItem and nextItem to preserve their original settings.
                    for rs in resolvedPath.dropFirst().dropLast() {
                        if case let .block(rrib) = rs {
                            completeItems.append(.block(.init(rrib.block, rrib.direction)))
                        }
                    }
                }

            case .failure:
                return partialItems
            }
            completeItems.append(nextItem)
            previousItem = nextItem
        }

        return completeItems
    }
}
