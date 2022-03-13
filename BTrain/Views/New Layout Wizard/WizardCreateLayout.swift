//
//  WizardCreateLayout.swift
//  BTrain
//
//  Created by Jean Bovet on 3/13/22.
//

import SwiftUI

struct WizardCreateLayout: View {
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Text("Creating Layout…")
                    .font(.largeTitle)
            }
            Spacer()
        }
    }
}

struct WizardCreateLayout_Previews: PreviewProvider {
    static var previews: some View {
        WizardCreateLayout()
    }
}
