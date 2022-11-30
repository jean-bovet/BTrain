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

final class PredefinedLayoutHelper: ObservableObject {
    var predefinedDocument: LayoutDocument?

    func load() throws {
        guard let file = Bundle.main.url(forResource: "Predefined", withExtension: "btrain") else {
            throw CocoaError(.fileNoSuchFile)
        }

        let fw = try FileWrapper(url: file, options: [])

        predefinedDocument = LayoutDocument(layout: try fw.layout())
        predefinedDocument!.locomotiveIconManager.setIcons(try fw.locomotiveIcons())
    }

    func create(layoutId: Identifier<Layout>, trains: Set<Identifier<Train>>, in document: LayoutDocument) {
        guard let predefinedDocument = predefinedDocument else {
            fatalError("Unable to create new layout because the predefined document is not defined!")
        }

        document.apply(LayoutFactory.createLayout(layoutId))

        document.layout.trains.elements.removeAll()
        document.layout.locomotives.elements.removeAll()

        for trainId in trains {
            if let train = predefinedDocument.layout.trains[trainId] {
                train.enabled = true
                train.wagonsLength = 0
                train.block = nil
                document.layout.trains.add(train)

                if let loc = predefinedDocument.layout.locomotives[train.locomotive?.id] {
                    loc.enabled = true
                    loc.length = 20
                    train.locomotive = loc
                    document.layout.locomotives.add(loc)

                    if let fileWrapper = predefinedDocument.locomotiveIconManager.fileWrapper(for: loc.id) {
                        document.locomotiveIconManager.setIcon(fileWrapper, locId: loc.id)
                    }
                }
            }
        }
    }
}
