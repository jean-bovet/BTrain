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

struct FeedbackEditListView: View {
    @ObservedObject var layout: Layout
    @State private var selection: Identifier<Feedback>? = nil
    
    @Environment(\.undoManager) var undoManager

    var body: some View {
        VStack {
            Table(selection: $selection) {
                
                TableColumn("Name") { feedback in
                    UndoProvider(feedback.name) { name in
                        TextField("Name", text: name)
                            .labelsHidden()
                    }
                }
                
                TableColumn("Device ID") { feedback in
                    UndoProvider(feedback.deviceID) { deviceID in
                        TextField("Device ID", value: deviceID,
                                  format: .number)
                    }
                }
                
                TableColumn("Contact ID") { feedback in
                    UndoProvider(feedback.contactID) { contactID in
                        TextField("Contact ID", value: contactID,
                                  format: .number)
                    }
                }
                
                TableColumn("State") { feedback in
                    FeedbackView(label: "", state: feedback.detected.wrappedValue)
                }
            } rows: {
                ForEach($layout.feedbacks) { feedback in
                    TableRow(feedback)
                }
            }
            HStack {
                Text("\(layout.feedbacks.count) feedbacks")
                
                Spacer()
                
                Button("+") {
                    let feedback = layout.newFeedback()
                    undoManager?.registerUndo(withTarget: layout, handler: { layout in
                        layout.feedbacks.removeAll { t in
                            return t.id == feedback.id
                        }
                    })
                }
                
                Button("-") {
                    if let feedback = layout.feedback(for: selection!) {
                        layout.remove(feedbackID: feedback.id)
                        undoManager?.registerUndo(withTarget: layout, handler: { layout in
                            layout.feedbacks.append(feedback)
                        })
                    }
                }.disabled(selection == nil)
                
                Spacer().fixedSpace()
                
                Button("􀄬") {
                    layout.sortFeedbacks()
                }
            }.padding()
        }
    }
}

struct FeedbackEditListView_Previews: PreviewProvider {
    static var previews: some View {
        FeedbackEditListView(layout: LayoutLoop2().newLayout())
    }
}
