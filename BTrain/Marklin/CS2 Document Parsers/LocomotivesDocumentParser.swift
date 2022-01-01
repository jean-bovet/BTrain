// Copyright 2021 Jean Bovet
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

struct Locomotive {
    var uid: UInt32?
    var name: String?
    var address: UInt32?
}

final class LocomotivesDocumentParser: CS2DocumentParser {
    
    /*
     [lokomotive]
     version
      .minor=3
     lokomotive
      .name=460 106-8 SBB
      .uid=0x4006
     */
    func parse() -> [Locomotive]? {
        guard matches("[lokomotive]") else {
            BTLogger.debug("Expecting [lokomotive] header as the first line")
            return nil
        }

        // Parse each section
        var locs = [Locomotive]()
        while let section = matchesSectionName() {
            switch(section) {
            case "lokomotive":
                locs.append(parseLokomotive())
                
            default:
                parseSectionAndIgnore()
            }
        }
        
        return locs
    }

    private func parseLokomotive() -> Locomotive {
        //  .name=460 106-8 SBB
        var loc = Locomotive()
        while let line = line, line.starts(with: ".") {
            if let name = valueFor(field: ".name=") {
                loc.name = name
            }
            if let uid = valueFor(field: ".uid=") {
                loc.uid = uid.valueFromHex
            }
            if let address = valueFor(field: ".adresse=") {
                loc.address = address.valueFromHex
            }
            lineIndex += 1
        }
        return loc
    }
    
}
