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

struct TrainIconView: View, DropDelegate {
        
    let trainIconManager: TrainIconManager
    @ObservedObject var train: Train
    
    let size: Size

    enum Size {
        case large
        case medium
    }
    
    var iconWidth: Double {
        switch(size) {
        case .large:
            return 200
        case .medium:
            return 100
        }
    }
    
    var iconHeight: Double {
        return iconWidth / 2
    }

    var body: some View {
        HStack {
            if let image = trainIconManager.imageFor(train: train) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
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
            item.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                DispatchQueue.main.async {
                    if let urlData = urlData as? Data {
                        let url = NSURL(absoluteURLWithDataRepresentation: urlData, relativeTo: nil) as URL
                        trainIconManager.setIcon(url, toTrain: train)
                    }
                }
            }
            
            return true
        } else {
            return false
        }
    }

}

struct TrainIconView_Previews: PreviewProvider {
    static var previews: some View {
        TrainIconView(trainIconManager: TrainIconManager(layout: Layout()), train: Train(), size: .large)
    }
}