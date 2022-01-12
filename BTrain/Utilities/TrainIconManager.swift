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

final class TrainIconManager {
    
    let layout: Layout
    var cache = NSCache<NSString, NSImage>()
    
    init(layout: Layout) {
        self.layout = layout
    }
    
    func imageFor(train: Train) -> NSImage? {
        if let image = cache.object(forKey: train.id.uuid as NSString) {
            return image
        }
        
        guard let imageURL = secureURL(from: train) else {
            return nil
        }
        
        if imageURL.startAccessingSecurityScopedResource() {
            defer {
                imageURL.stopAccessingSecurityScopedResource()
            }
            if let image = NSImage(contentsOf: imageURL) {
                cache.setObject(image, forKey: train.id.uuid as NSString)
                return image
            }
        }
        return nil
    }
    
    func setIcon(_ url: URL, toTrain train: Train) {
        train.iconUrlData = bookmarkDataFor(url)
        cache.removeObject(forKey: train.id.uuid as NSString)
    }
    
    private func bookmarkDataFor(_ url: URL) -> Data? {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            return bookmarkData
        } catch {
            BTLogger.error("Unable to create a bookmark data for \(url): \(error)")
            return nil
        }
    }
    
    private func secureURL(from train: Train) -> URL? {
        guard let bookmarkData = train.iconUrlData else {
            return nil
        }
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale {
                train.iconUrlData = bookmarkDataFor(url)
            }
            return url
        } catch {
            BTLogger.error("Error resolving bookmark data: \(error)")
            return nil
        }
    }
    
}
