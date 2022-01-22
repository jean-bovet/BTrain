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

import AppKit

extension FileWrapper {
    
    func layout() throws -> Layout {
        guard let files = fileWrappers else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        guard let layoutFile = files.first(where: {$0.value.filename == LayoutDocument.layoutFileName }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        guard let data = layoutFile.value.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let layout = try LayoutDocument.layout(contentType: .json, data: data)
        return layout
    }
    
    func icons() throws -> [(Identifier<Train>,NSImage)] {
        guard let files = fileWrappers else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        var items = [(Identifier<Train>,NSImage)]()
        if let iconDirectory = files.first(where: {$0.value.isDirectory})?.value, let files = iconDirectory.fileWrappers?.values {
            for file in files {
                guard let filename = file.filename else {
                    continue
                }
                let trainId = (filename as NSString).deletingPathExtension
                
                guard let data = file.regularFileContents else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                
                guard let image = NSImage(data: data) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                
                items.append((Identifier<Train>(uuid: trainId), image))
            }
        }
        return items
    }
    
}
