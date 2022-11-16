//
//  FeedbackDetailsView.swift
//  BTrain
//
//  Created by Jean Bovet on 11/16/22.
//

import SwiftUI

struct FeedbackDetailsView: View {
    
    @ObservedObject var layout: Layout

    @ObservedObject var feedback: Feedback

    var body: some View {
        Form {
            UndoProvider($feedback.deviceID) { deviceID in
                TextField("Device ID", value: deviceID,
                          format: .number)
            }
            
            UndoProvider($feedback.contactID) { contactID in
                TextField("Contact ID", value: contactID,
                          format: .number)
            }
            
            FeedbackView(label: "", state: $feedback.detected)
                .frame(maxWidth: 50)
        }.padding()
    }
}

struct FeedbackDetailsView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: Layout())
    
    static var previews: some View {
        FeedbackDetailsView(layout: doc.layout, feedback: Feedback(id: .init(uuid: "foo")))
    }
}
