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
import SwiftUI
import UniformTypeIdentifiers

extension LayoutDocument: ReferenceFileDocument {
    
    static let packageType = UTType("ch.arizona-software.BTrain")!
    
    static var readableContentTypes: [UTType] { [.json, packageType] }
    
    static let layoutFileName = "layout.json"
    
    convenience init(configuration: ReadConfiguration) throws {
        switch configuration.contentType {
        case .json:
            guard let data = configuration.file.regularFileContents else {
                throw CocoaError(.fileReadCorruptFile)
            }

            let layout = try LayoutDocument.layout(contentType: configuration.contentType, data: data)
            self.init(layout: layout)
            
        case LayoutDocument.packageType:
            self.init(layout: try configuration.file.layout())
            trainIconManager.setIcons(try configuration.file.icons())

        default:
            throw CocoaError(.fileReadUnsupportedScheme)
        }

    }
    
    func fileWrapper(snapshot: Data, configuration: WriteConfiguration) throws -> FileWrapper {
        switch configuration.contentType {
        case .json:
            return .init(regularFileWithContents: snapshot)
            
        case LayoutDocument.packageType:
            let wrapper = FileWrapper(directoryWithFileWrappers: [:])
            
            let jsonFile = FileWrapper(regularFileWithContents: snapshot)
            jsonFile.preferredFilename = LayoutDocument.layoutFileName
            wrapper.addFileWrapper(jsonFile)
            
            let iconDirectory = FileWrapper(directoryWithFileWrappers: [:])
            iconDirectory.preferredFilename = "icons"
            
            for train in layout.trains {
                if let icon = trainIconManager.imageFor(train: train) {
                    if let jpegData = icon.jpegData() {
                        iconDirectory.addRegularFile(withContents: jpegData, preferredFilename: "\(train.uuid).jpg")
                    } else if let data = icon.tiffRepresentation(using: .lzw, factor: 0) {
                        iconDirectory.addRegularFile(withContents: data, preferredFilename: "\(train.uuid).tiff")
                    }
                }
            }
            
            wrapper.addFileWrapper(iconDirectory)
            
            return wrapper
            
        default:
            throw CocoaError(.fileWriteUnsupportedScheme)
        }
    }

    static func layout(contentType: UTType, data: Data) throws -> Layout {
        guard contentType == .json else {
            throw CocoaError(.fileReadUnknown)
        }
        let decoder = JSONDecoder()
        let layout = try decoder.decode(Layout.self, from: data)
        // Upon decoding, remove all train reservations as these will be computed on-demand
        // when the trains start moving again.
        layout.freeAllTrains(removeFromLayout: false)
        return layout
    }
    
    func snapshot(contentType: UTType) throws -> Data {
        let encoder = JSONEncoder()
        let data = try encoder.encode(layout)
        return data
    }

}
