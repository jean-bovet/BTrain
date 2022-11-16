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

/// This view enables the user to add a feedback by automatically detecting its contact and device ID using the Digital Controller:
/// - Each time the user activates a feedback in the layout, its addresses will be reported in this view.
struct FeedbackAddView: View {
    
    @ObservedObject var doc: LayoutDocument
    @ObservedObject var layoutController: LayoutController

    @Binding var newFeedback: FeedbackEditListView.NewFeedback

    @State private var name = ""
    
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(alignment: .leading) {
            if let feedback = layoutController.lastDetectedFeedback {
                Text("Last detected feedback has Device ID = \(feedback.deviceID) and Contact ID = \(feedback.contactID)")
                    .fixedSize()
            } else {
                Text("Activate a feedback in the layout and it will be automatically detected here")
                    .fixedSize()
            }
            HStack {
                Text("Name:")
                TextField("", text: $name)
            }
            HStack {
                Spacer()
                
                Button("Cancel") {
                    newFeedback = FeedbackEditListView.NewFeedback.empty()
                    presentationMode.wrappedValue.dismiss()
                }.keyboardShortcut(.cancelAction)
                
                Button("Add") {
                    if let feedback = layoutController.lastDetectedFeedback {
                        newFeedback = FeedbackEditListView.NewFeedback(name: name, deviceID: feedback.deviceID, contactID: feedback.contactID)
                    } else {
                        newFeedback = FeedbackEditListView.NewFeedback.empty()
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(layoutController.lastDetectedFeedback == nil || name.isEmpty)
            }
        }
        .onAppear() {
            layoutController.lastDetectedFeedback = nil
            if doc.simulator.started {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    layoutController.lastDetectedFeedback = .init(deviceID: UInt16.random(in: 1..<10), contactID: UInt16.random(in: 1..<100))
                }
            }
        }
        .frame(minWidth: 400)
    }
}

struct FeedbackAddView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutYard().newLayout())
    static let feedback = FeedbackEditListView.NewFeedback.empty()
    
    static var previews: some View {
        FeedbackAddView(doc: doc, layoutController: doc.layoutController, newFeedback: .constant(feedback))
    }
}
