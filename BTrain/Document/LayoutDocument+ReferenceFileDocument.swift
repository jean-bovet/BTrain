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
    static var writableContentTypes: [UTType] { [ packageType] }
    
    static let layoutFileName = "layout.json"
    
    convenience init(configuration: ReadConfiguration) throws {
        try self.init(contentType: configuration.contentType, file: configuration.file)
    }
    
    convenience init(contentType: UTType, file: FileWrapper) throws {
        switch contentType {
        case .json:
            guard let data = file.regularFileContents else {
                throw CocoaError(.fileReadCorruptFile)
            }

            let layout = try LayoutDocument.layout(contentType: contentType, data: data)
            self.init(layout: layout)
            
        case LayoutDocument.packageType:
            self.init(layout: try file.layout())
            trainIconManager.setIcons(try file.icons())

        default:
            throw CocoaError(.fileReadUnsupportedScheme)
        }
    }

    func fileWrapper(snapshot: Data, configuration: WriteConfiguration) throws -> FileWrapper {
        try fileWrapper(snapshot: snapshot, contentType: configuration.contentType)
    }
    
    func fileWrapper(snapshot: Data, contentType: UTType) throws -> FileWrapper {
        switch contentType {
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
                if let icon = trainIconManager.icon(for: train.id) {
                    let key: String?
                    if let pngData = icon.pngData() {
                        key = iconDirectory.addRegularFile(withContents: pngData, preferredFilename: "\(train.uuid).png")
                    } else if let data = icon.tiffRepresentation(using: .lzw, factor: 0) {
                        key = iconDirectory.addRegularFile(withContents: data, preferredFilename: "\(train.uuid).tiff")
                    } else {
                        key = nil
                    }
                    
                    // Update the FileWrapper inside the icon manager so it points to the most up to date FileWrapper definition
                    if let key = key {
                        if let fw = iconDirectory.fileWrappers?[key] {
                            trainIconManager.setFileWrapper(fw, for: train.id)
                        } else {
                            BTLogger.error("Unable to retrieve the file wrapper for \(key)")
                            throw CocoaError(.fileWriteUnknown)
                        }
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
        return try Layout.decode(from: data)
    }
    
    func snapshot(contentType: UTType) throws -> Data {
        try layout.encode()
    }

}
