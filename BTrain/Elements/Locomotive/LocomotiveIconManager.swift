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

/// This class manages the icons associated with each locomotive.
///
/// Each icon is stored on the disk using a FileWrapper reference. An in-memory
/// cache is used to return the icon image immediately; this cache can
/// be cleared at anytime and the icon reloaded from disk.
///
/// Note: when saving the ``LayoutDocument``, all the icons will be saved inside the document
/// package after the appropriate conversion.
final class LocomotiveIconManager: ObservableObject {
    private var fileWrappers = [Identifier<Locomotive>: FileWrapper]()
    private let imageCache = NSCache<NSString, NSImage>()

    func fileWrapper(for locId: Identifier<Locomotive>) -> FileWrapper? {
        fileWrappers[locId]
    }

    func setFileWrapper(_ fw: FileWrapper, for locId: Identifier<Locomotive>) {
        fileWrappers[locId] = fw
    }

    func icon(for locId: Identifier<Locomotive>?) -> NSImage? {
        guard let locId = locId else {
            return nil
        }

        // Return from cache if it exists
        if let image = imageCache.object(forKey: locId.uuid as NSString) {
            return image
        }

        // Load the icon from disk
        if let url = fileWrappers[locId] {
            return load(url, locId: locId)
        }

        return nil
    }

    /// Set the icon data to a specific locomotive.
    ///
    /// The icon data will be saved to a temporary directory until the document is saved, at which point
    /// the icon will be saved in the document package itself.
    /// - Parameters:
    ///   - data: the icon data
    ///   - locId: the locomotive
    func setIcon(_ data: Data, locId: Identifier<Locomotive>) throws {
        let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let temporaryIconFile = temporaryDirectoryURL.appending(path: UUID().uuidString)
        try data.write(to: temporaryIconFile)
        setIcon(try FileWrapper(url: temporaryIconFile), locId: locId)
    }

    func setIcon(_ url: FileWrapper, locId: Identifier<Locomotive>) {
        objectWillChange.send()
        fileWrappers[locId] = url
        _ = load(url, locId: locId)
    }

    func setIcons(_ icons: [(Identifier<Locomotive>, FileWrapper)]) {
        clear()
        for value in icons {
            setIcon(value.1, locId: value.0)
        }
    }

    private func load(_: FileWrapper, locId: Identifier<Locomotive>) -> NSImage? {
        guard let url = fileWrappers[locId] else {
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

        imageCache.setObject(image, forKey: locId.uuid as NSString)

        return image
    }

    func clear() {
        objectWillChange.send()
        imageCache.removeAllObjects()
        fileWrappers.removeAll()
    }

    func removeIconFor(loc: Locomotive?) {
        guard let loc = loc else {
            return
        }
        objectWillChange.send()
        imageCache.removeObject(forKey: loc.id.uuid as NSString)
        fileWrappers[loc.id] = nil
    }

    // Use this method to remove all in-memory images from the cache.
    // The next time an image is requested, it will be re-loaded from disk.
    func clearInMemoryCache() {
        imageCache.removeAllObjects()
    }
}
