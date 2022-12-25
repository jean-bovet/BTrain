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

import SwiftUI
import UniformTypeIdentifiers

struct LocomotiveIconView: View, DropDelegate {
    @ObservedObject var locomotiveIconManager: LocomotiveIconManager
    @ObservedObject var loc: Locomotive

    let size: Size
    let hideIfNotDefined: Bool

    enum Size {
        case large
        case medium
        case small
    }

    var iconWidth: Double {
        switch size {
        case .large:
            return 200
        case .medium:
            return 100
        case .small:
            return 50
        }
    }

    var iconHeight: Double {
        iconWidth / 2
    }

    var body: some View {
        HStack {
            if let image = locomotiveIconManager.icon(for: loc.id) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconWidth, height: iconHeight)
            } else if hideIfNotDefined {
                Rectangle()
                    .background(.clear)
                    .foregroundColor(.clear)
                    .frame(width: iconWidth, height: iconHeight)
            } else {
                Rectangle()
                    .foregroundColor(.gray)
                    .border(Color.black)
                    .frame(width: iconWidth, height: iconHeight)
            }
        }.onDrop(of: [.fileURL], delegate: self)
    }

    func performDrop(info: DropInfo) -> Bool {
        if let item = info.itemProviders(for: [.fileURL]).first {
            item.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { urlData, error in
                DispatchQueue.main.async {
                    if let urlData = urlData as? Data {
                        let url = NSURL(absoluteURLWithDataRepresentation: urlData, relativeTo: nil) as URL
                        do {
                            let fw = try FileWrapper(url: url)
                            locomotiveIconManager.setIcon(fw, locId: loc.id)
                        } catch {
                            BTLogger.error("Unable to create the image for \(url): \(error)")
                        }
                    }
                }
            }

            return true
        } else {
            return false
        }
    }
}

struct LocomotiveIconView_Previews: PreviewProvider {
    static var previews: some View {
        LocomotiveIconView(locomotiveIconManager: LocomotiveIconManager(), loc: Locomotive(), size: .large, hideIfNotDefined: false)
    }
}
