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

typealias QueryLocomotivesResult = Result<[CommandLocomotive], Error>

/// Fetches the locomotive definitions and icons from the Central Station by using an HTTP request.
/// See ``MarklinCS3`` for more information.
struct MarklinFetchLocomotives {    
    /// Fetch the locomotive commands from the specified Central Station URL
    /// - Parameters:
    ///   - server: the URL of the Central Station (can also be a local file for testing)
    ///   - completion: an array of locomotive commands or nil
    func fetchLocomotives(server: URL, completion: @escaping (QueryLocomotivesResult) -> Void) {
        Task {
            let cs3 = MarklinCS3()
            do {
                let loks = try await cs3.fetchLoks(server: server)
                let cmdLoks = await convert(loks, url: server)
                completion(.success(cmdLoks))
            } catch {
                BTLogger.error("Error fetching the locomotives: \(error)")
                completion(.failure(error))
            }
        }
    }

    private func convert(_ loks: [MarklinCS3.Lok], url: URL) async -> [CommandLocomotive] {
        var cmdLoks = [CommandLocomotive]()
        for lok in loks {
            await cmdLoks.append(convert(lok, url: url))
        }
        return cmdLoks
    }

    private func convert(_ lok: MarklinCS3.Lok, url: URL) async -> CommandLocomotive {
        let icon = await fetchIcon(from: url, for: lok)
        let cmdLok = lok.toCommand(icon: icon)
        return cmdLok
    }

    private func fetchIcon(from url: URL, for lok: MarklinCS3.Lok) async -> Data? {
        do {
            let cs3 = MarklinCS3()
            let data = try await cs3.fetchLokIcon(server: url, lok: lok)
            if let data = data, data.isEmpty {
                // Empty data should be returned as nil
                return nil
            } else {
                return data
            }
        } catch {
            BTLogger.error("Error fetching the icon for locomotive \(lok): \(error)")
            return nil
        }
    }
}
