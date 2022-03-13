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

struct NewLayoutWizardView: View {
    
    @ObservedObject var document: LayoutDocument

    @StateObject var helper = PredefinedLayoutHelper()
    
    @State private var errorString: String?
    
    @State private var selectedLayout = LayoutEmptyCreator.id
    @State private var selectedTrains = Set<Identifier<Train>>()

    enum Stage {
        case selectLayout
        case selectLocomotive
        case createLayout
    }
    
    @State private var wizardStage: Stage = .selectLayout
    
    var nextButtonEnabled: Bool {
        switch wizardStage {
        case .selectLayout:
            return true
        case .selectLocomotive:
            return !selectedTrains.isEmpty
        case .createLayout:
            return false
        }
    }
    
    var body: some View {
        VStack {
            switch wizardStage {
            case .selectLayout:
                WizardSelectLayout(selectedLayout: $selectedLayout)

            case .selectLocomotive:
                WizardSelectLocomotive(document: helper.predefinedDocument!, selectedTrains: $selectedTrains)

            case .createLayout:
                WizardCreateLayout()
            }

            HStack {
                Spacer()
                Button("Previous") {
                    wizardStage = .selectLayout
                }
                .disabled(wizardStage == .selectLayout || wizardStage == .createLayout)
                
                Button("Next") {
                    switch wizardStage {
                    case .selectLayout:
                        if helper.predefinedDocument == nil {
                            do {
                                try helper.load()
                            } catch {
                                errorString = error.localizedDescription
                            }
                        }
                        wizardStage = .selectLocomotive

                    case .selectLocomotive:
                        wizardStage = .createLayout
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            helper.create(layoutId: selectedLayout, trains: selectedTrains, in: document)
                            document.layout.newLayoutWizardExecuted = true
                        }

                    case .createLayout:
                        break
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!nextButtonEnabled)
                .padding([.trailing])
            }
            Spacer()

            if let errorString = errorString {
                Spacer()
                Text(errorString)
                    .foregroundColor(.red)
            }
            Spacer()
        }.frame(minWidth: 800, minHeight: 600)
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        NewLayoutWizardView(document: LayoutDocument(layout: Layout()))
            .preferredColorScheme(.light)
        NewLayoutWizardView(document: LayoutDocument(layout: Layout()))
            .preferredColorScheme(.dark)
    }
}
