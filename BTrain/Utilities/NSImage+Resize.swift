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

// Source: https://gist.github.com/MaciejGad/11d8469b218817290ee77012edb46608
extension NSImage {
    /// Returns the height of the current image.
    var height: CGFloat {
        size.height
    }

    /// Returns the width of the current image.
    var width: CGFloat {
        size.width
    }

    /// Returns a png representation of the current image.
    var PNGRepresentation: Data? {
        if let tiff = tiffRepresentation, let tiffData = NSBitmapImageRep(data: tiff) {
            return tiffData.representation(using: .png, properties: [:])
        }

        return nil
    }

    ///  Copies the current image and resizes it to the given size.
    ///
    ///  - parameter size: The size of the new image.
    ///
    ///  - returns: The resized copy of the given image.
    func copy(size: NSSize) -> NSImage? {
        // Create a new rect with given width and height
        let frame = NSMakeRect(0, 0, size.width, size.height)

        // Get the best representation for the given size.
        guard let rep = bestRepresentation(for: frame, context: nil, hints: nil) else {
            return nil
        }

        // Create an empty image with the given size.
        let img = NSImage(size: size)

        // Set the drawing context and make sure to remove the focus before returning.
        img.lockFocus()
        defer { img.unlockFocus() }

        // Draw the new image
        if rep.draw(in: frame) {
            return img
        }

        // Return nil in case something went wrong.
        return nil
    }

    ///  Copies the current image and resizes it to the size of the given NSSize, while
    ///  maintaining the aspect ratio of the original image.
    ///
    ///  - parameter size: The size of the new image.
    ///
    ///  - returns: The resized copy of the given image.
    func resizeWhileMaintainingAspectRatioToSize(size: NSSize) -> NSImage? {
        let newSize: NSSize

        let widthRatio = size.width / width
        let heightRatio = size.height / height

        if widthRatio > heightRatio {
            newSize = NSSize(width: floor(width * widthRatio), height: floor(height * widthRatio))
        } else {
            newSize = NSSize(width: floor(width * heightRatio), height: floor(height * heightRatio))
        }

        return copy(size: newSize)
    }

    ///  Copies and crops an image to the supplied size.
    ///
    ///  - parameter size: The size of the new image.
    ///
    ///  - returns: The cropped copy of the given image.
    func crop(size: NSSize) -> NSImage? {
        // Resize the current image, while preserving the aspect ratio.
        guard let resized = resizeWhileMaintainingAspectRatioToSize(size: size) else {
            return nil
        }
        // Get some points to center the cropping area.
        let x = floor((resized.width - size.width) / 2)
        let y = floor((resized.height - size.height) / 2)

        // Create the cropping frame.
        let frame = NSMakeRect(x, y, size.width, size.height)

        // Get the best representation of the image for the given cropping frame.
        guard let rep = resized.bestRepresentation(for: frame, context: nil, hints: nil) else {
            return nil
        }

        // Create a new image with the new size
        let img = NSImage(size: size)

        img.lockFocus()
        defer { img.unlockFocus() }

        if rep.draw(in: NSMakeRect(0, 0, size.width, size.height),
                    from: frame,
                    operation: NSCompositingOperation.copy,
                    fraction: 1.0,
                    respectFlipped: false,
                    hints: [:])
        {
            // Return the cropped image.
            return img
        }

        // Return nil in case anything fails.
        return nil
    }

    ///  Saves the PNG representation of the current image to the HD.
    ///
    /// - parameter url: The location url to which to write the png file.
    func savePNGRepresentationToURL(url: URL) throws {
        if let png = PNGRepresentation {
            try png.write(to: url, options: .atomicWrite)
        }
    }
}
