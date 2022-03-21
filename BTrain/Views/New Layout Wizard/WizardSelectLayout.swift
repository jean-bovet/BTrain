//
//  WizardSelectLayout.swift
//  BTrain
//
//  Created by Jean Bovet on 3/13/22.
//

import SwiftUI

struct WizardSelectLayout: View {

    @Binding var selectedLayout: Identifier<Layout>

    @Environment(\.colorScheme) var colorScheme

    let previewSize = CGSize(width: 300, height: 200)

    var backgroundColor: Color {
        if colorScheme == .dark {
            return Color(NSColor.windowBackgroundColor)
        } else {
            return .white
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Select a Layout:")
                .font(.largeTitle)
                .padding()
            ScrollView(.horizontal) {
                LazyHStack {
                    ForEach(LayoutFactory.GlobalLayoutIDs, id:\.self) { layout in
                        ZStack {
                            Rectangle()
                                .frame(width: previewSize.width, height: previewSize.height)
                                .cornerRadius(5)
                                .foregroundColor(backgroundColor)
                                .shadow(radius: 5)
                            SwitchboardPreview(previewSize: previewSize, layoutId: layout)
                                .frame(width: previewSize.width, height: previewSize.height)
                            Rectangle()
                                .frame(width: previewSize.width, height: previewSize.height)
                                .background(.clear)
                                .foregroundColor(.clear)
                                .border(.tint, width: 3)
                                .hidden(layout != selectedLayout)
                        }
                        .onTapGesture {
                            selectedLayout = layout
                        }
                        .padding()
                    }
                }
            }
        }
    }

}

struct SwitchboardPreview: View {
    
    let previewSize: CGSize
    let layoutId: Identifier<Layout>

    var layout: Layout {
        return LayoutFactory.createLayout(layoutId)
    }
    
    var switchboard: SwitchBoard {
        return SwitchBoardFactory.generateSwitchboard(layout: layout, simulator: nil, trainIconManager: nil)
    }
    
    var coordinator: LayoutController {
        return LayoutController(layout: layout, switchboard: switchboard, interface: MarklinInterface())
    }
    
    var scale: Double {
        let r1 = previewSize.width/switchboard.idealSize.width
        let r2 = previewSize.height/switchboard.idealSize.height
        return min(r1, r2)
    }
    
    var body: some View {
        Group {
            if layoutId == LayoutEmptyCreator.id {
                Text("Empty Layout")
            } else {
                SwitchBoardView(switchboard: switchboard,
                                state: switchboard.state,
                                layout: layout,
                                layoutController: coordinator,
                                gestureEnabled: false)
                    .frame(width: switchboard.idealSize.width, height: switchboard.idealSize.height)
                    .scaleEffect(scale)
            }
        }
    }
}

struct WizardSelectLayout_Previews: PreviewProvider {
    static var previews: some View {
        WizardSelectLayout(selectedLayout: .constant(LayoutFactory.GlobalLayoutIDs[0]))
    }
}
