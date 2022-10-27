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
import Gzip

final class MarklinLocomotiveConfig {
    
    enum Status {
        case unknown
        case error
        case processing
        case completed(loc: [Locomotive])
    }
        
    private var configDataLength = 0
    private var configData = [UInt8]()

    func process(_ cmd: MarklinCommand) -> Status {
        guard case .configDataStream(length: let length, data: let data, descriptor: _) = cmd else {
            return .unknown
        }
        
        if let length = length {
            BTLogger.debug(("Length is \(length)"))
            configDataLength = Int(length)
            configData.removeAll()
            return .processing
        } else if configDataLength > 0 {
            configData.append(contentsOf: data)
            BTLogger.debug("Received \(configData.count) so far")
            
            if configData.count >= configDataLength && configDataLength >= 4 {
                // Remove the first 4 bytes which is probably the CRC value
                // but is not part of the gzip data itself.
                let actualData = configData[4..<configDataLength]
                
                do {
                    let data = Data(actualData)
                    // Note: the data cannot be uncompressed using the Apple's decompression API
                    // (nor with the default tools in the Finder). The data is a valid zlib
                    // compressed but somehow something is preventing it from being decompressed
                    // by the standard API. I had to rely on the Gzip for Swift wrapper (https://github.com/1024jp/GzipSwift)
                    // to de-compress.
                    let uncompressed = try data.gunzipped()
                    if let locomotives = parse(data: uncompressed) {
                        return .completed(loc: locomotives)
                    } else {
                        return .error
                    }
                } catch {
                    BTLogger.error("Unable to decompress because \(error)")
                    return .error
                }
            } else {
                return .processing
            }
        } else {
            return .unknown
        }
    }
    
    private func parse(data: Data) -> [Locomotive]? {
        let text = String(decoding: data, as: UTF8.self)
        let parser = LocomotivesDocumentParser(text: text)
        if let locomotives = parser.parse() {
            return locomotives
        } else {
            BTLogger.error("Unable to parse locomotives from \(text)")
            return nil
        }
    }
}
