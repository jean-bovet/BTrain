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
            
    func fetchResources(server: URL, _ completion: @escaping CompletionBlock) {
        Task {
            let cs3 = MarklinCS3()
            do {
                self.functions = try await cs3.fetchFunctions(server: server)
                self.svgSprites = try await cs3.fetchSvgSprites(server: server)
                completion()
            } catch {
                BTLogger.error("Error fetching the functions: \(error)")
                completion()
            }
        }
    }
    
    func locomotiveFunctions() -> [CommandLocomotiveFunctionAttributes] {
        guard let functions = functions else {
            return []
        }
        var all = [CommandLocomotiveFunctionAttributes]()
        for group in functions.gruppe {
            for f in group.icon {
                if let type = f.typeCompatibility, let typeInt = UInt32(type) {
                    let typeIcon = String(format: "%03d", typeInt)
                    let activeName = "fkticon_a_\(typeIcon).svg"
                    let inactiveName = "fkticon_i_\(typeIcon).svg"
                    let activeSvgIcon = svgSprites?[activeName]
                    let inactiveSvgIcon = svgSprites?[inactiveName]
                    let attributes = CommandLocomotiveFunctionAttributes(type: typeInt,
                                                                         name: f.kurztitel,
                                                                         activeSvgIcon: activeSvgIcon,
                                                                         inactiveSvgIcon: inactiveSvgIcon)
                    all.append(attributes)
                }
            }
        }
        return all
    }
}
