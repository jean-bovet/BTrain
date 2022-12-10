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

final class MarklinInterfaceResources {
    /// The list of function definitions which is global to the CS3. This is where
    /// each function name and icon name are defined.
    private var functions: MarklinCS3.Functions?
    
    /// This is the SVG definition of each icon referenced by each function.
    private var svgSprites: MarklinCS3.SvgSprites?
        
    func attributes(about function: CommandLocomotiveFunction) -> CommandLocomotiveFunctionAttributes? {
        guard let functions = functions else {
            return nil
        }
        for group in functions.gruppe {
            for f in group.icon {
                guard let type = f.type else {
                    continue
                }
                if UInt32(type) == function.type {
                    return .init(name: f.kurztitel, svgIcon: svgSprites?["\(f.name).svg"])
                }
            }
        }
        return nil
    }
    
    func fetchResources(server: String, _ completion: @escaping CompletionBlock) {
        guard let url = URL(string: "http://\(server)") else {
            completion()
            return
        }

        Task {
            let cs3 = MarklinCS3()
            do {
                self.functions = try await cs3.fetchFunctions(server: url)
                self.svgSprites = try await cs3.fetchSvgSprites(server: url)
                completion()
            } catch {
                BTLogger.error("Error fetching the functions: \(error)")
                completion()
            }
        }

    }
    
}
