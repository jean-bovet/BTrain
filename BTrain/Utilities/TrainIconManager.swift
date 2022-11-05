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

/// This class manages the icons associated with each train.
///
/// Each icon is stored on the disk using a FileWrapper reference. An in-memory
/// cache is used to return the icon image immediately; this cache can
/// be cleared at anytime and the icon reloaded from disk.
///
/// Note: when saving the ``LayoutDocument``, all the icons will be saved inside the document
/// package after the appropriate conversion.
final class TrainIconManager: ObservableObject {
    
    private var fileWrappers = [Identifier<Train>:FileWrapper]()
    private let imageCache = NSCache<NSString, NSImage>()
    
    func fileWrapper(for trainId: Identifier<Train>) -> FileWrapper? {
        fileWrappers[trainId]
    }
    
    func setFileWrapper(_ fw: FileWrapper, for trainId: Identifier<Train>) {
        fileWrappers[trainId] = fw
    }
    
    func icon(for trainId: Identifier<Train>) -> NSImage? {
        // Return from cache if it exists
        if let image = imageCache.object(forKey: trainId.uuid as NSString) {
            return image
        }
        
        // Load the icon from disk
        if let url = fileWrappers[trainId] {
            return load(url, trainId: trainId)
        }
        
        return nil
    }
    
    /// Set the icon data to a specific train.
    ///
    /// The icon data will be saved to a temporary directory until the document is saved, at which point
    /// the icon will be saved in the document package itself.
    /// - Parameters:
    ///   - data: the icon data
    ///   - trainId: the train
    func setIcon(_ data: Data, toTrainId trainId: Identifier<Train>) throws {
        let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let temporaryIconFile = temporaryDirectoryURL.appending(path: UUID().uuidString)
        try data.write(to: temporaryIconFile)
        setIcon(try FileWrapper(url: temporaryIconFile), toTrainId: trainId)
    }
    
    func setIcon(_ url: FileWrapper, toTrainId trainId: Identifier<Train>) {
        objectWillChange.send()
        fileWrappers[trainId] = url
        _ = load(url, trainId: trainId)
    }
    
    func setIcons(_ icons: [(Identifier<Train>,FileWrapper)]) {
        clear()
        for value in icons {
            setIcon(value.1, toTrainId: value.0)
        }
    }
    
    private func load(_ url: FileWrapper, trainId: Identifier<Train>) -> NSImage? {
        guard let url = fileWrappers[trainId] else {
            return nil
        }
        
        guard let data = url.regularFileContents else {
            BTLogger.error("Unable to retrieve the content of \(url)")
            return nil
        }
        
        guard let image = NSImage(data: data) else {
            BTLogger.error("Invalid image format for \(url)")
            return nil
        }
        
        imageCache.setObject(image, forKey: trainId.uuid as NSString)
        
        return image
    }

    func clear() {
        objectWillChange.send()
        imageCache.removeAllObjects()
        fileWrappers.removeAll()
    }
    
    func removeIconFor(train: Train) {
        objectWillChange.send()
        imageCache.removeObject(forKey: train.id.uuid as NSString)
        fileWrappers[train.id] = nil
    }

    // Use this method to remove all in-memory images from the cache.
    // The next time an image is requested, it will be re-loaded from disk.
    func clearInMemoryCache() {
        imageCache.removeAllObjects()
    }
}
