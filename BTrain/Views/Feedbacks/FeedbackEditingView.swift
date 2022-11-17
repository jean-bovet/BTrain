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

struct FeedbackEditingView: View {
    
    @ObservedObject var doc: LayoutDocument
    @ObservedObject var layout: Layout
    @ObservedObject var layoutController: LayoutController
    
    @State private var showAddNewFeedback = false
    
    struct NewFeedback: Equatable {
        let name: String
        let deviceID: UInt16
        let contactID: UInt16
        
        static func empty() -> NewFeedback {
            NewFeedback(name: "", deviceID: 0, contactID: 0)
        }
    }
    
    @State private var newFeedback = NewFeedback.empty()
    
    @Environment(\.undoManager) var undoManager

    var body: some View {
        LayoutElementsEditingView(layout: layout, new: {
            layout.newFeedback()
        }, delete: { feedback in
            layout.remove(feedbackID: feedback.id)
        }, duplicate: { feedback in
            layout.duplicate(feedback: feedback)
        }, sort: {
            layout.feedbacks.elements.sort {
                $0.name < $1.name
            }
        }, elementContainer: $layout.feedbacks, more: {
            if doc.connected {
                Button("􀥄") {
                    showAddNewFeedback.toggle()
                }
            }
        }, row: { feedback in
            HStack {
                UndoProvider(feedback) { feedback in
                    TextField("Name", text: feedback.name)
                }
                FeedbackView(label: "", state: feedback.detected)
                    .frame(maxWidth: 50)
            }.labelsHidden()
        }) { feedback in
            FeedbackDetailsView(layout: layout, feedback: feedback)
        }
        .sheet(isPresented: $showAddNewFeedback, onDismiss: {
            if newFeedback != NewFeedback.empty() {
                addNewFeedback(name: newFeedback.name, deviceID: newFeedback.deviceID, contactID: newFeedback.contactID)
            }
        }) {
            FeedbackAddView(doc: doc, layoutController: layoutController, newFeedback: $newFeedback)
                .padding()
        }
    }
    
    func addNewFeedback(name: String = "", deviceID: UInt16 = 0, contactID: UInt16 = 0) {
        let feedback = layout.newFeedback()
        feedback.name = name
        feedback.deviceID = deviceID
        feedback.contactID = contactID
        undoManager?.registerUndo(withTarget: layout, handler: { layout in
            layout.feedbacks.remove(feedback.id)
        })
    }
}

struct FeedbackEditingView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutLoop2().newLayout())
    
    static var previews: some View {
        ConfigurationSheet(title: "Feedbacks") {
            FeedbackEditingView(doc: doc, layout: doc.layout, layoutController: doc.layoutController)
        }
    }
}
