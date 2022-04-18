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

import Foundation

enum DragState {
    // No drag operation is happening
    case none
    
    // The shape is being dragged
    case dragging
    
    // The plug of a shape is being dragged, for example
    // the extremity of a link shape.
    case draggingPlug
    
    // The shape is being rotated
    case rotating
    
    // No action to take, ignore the dragging operation
    case ignore
}

final class SwitchBoardDragOperation {
    
    let layout: Layout
    let renderer: SwitchBoardRenderer
    let provider: ShapeProviding
    var state: SwitchBoard.State
    
    var selectedPlugId: Int?
    
    var originalCenter: CGPoint = .zero
    
    // The original angle value of the shape before rotation
    var originalAngle: CGFloat = 0
    
    // The delta rotation value when the shape is rotated
    var deltaRotationAngle: CGFloat = 0
    
    // State of the drag operation
    var dragState: DragState = .none
        
    // Snapshot of the layout used to restore state in
    // case the user undo the last drag operation
    var snapshot: Data?
    
    init(layout: Layout, state: SwitchBoard.State, provider: ShapeProviding, renderer: SwitchBoardRenderer) {
        self.layout = layout
        self.state = state
        self.provider = provider
        self.renderer = renderer
    }

    func performAction(at location: CGPoint) -> Bool {
        for shape in provider.actionableShapes {
            if shape.performAction(at: location) {
                return true
            }
        }
        return false
    }

    func saveState() {
        snapshot = try? layout.encode()
    }
    
    func restoreState() {
        if let snapshot = snapshot {
            try? layout.restore(from: snapshot)
        }
        snapshot = nil
    }

    func onDragChanged(location: CGPoint, translation: CGSize) {
        if dragState == .none {
            saveState()
            
            // Try to see if there is an action that a shape can perform
            // at the location of the tap, and if so, ignore the rest of the gesture.
            if !state.editable {
                if performAction(at: location) {
                    dragState = .ignore
                } else {
                    dragState = .ignore
                    for provider in provider.dragOnTapProviders {
                        if let shape = provider.draggableShape(at: location) {
                            state.ephemeralDraggableShape = shape
                            originalCenter = shape.center
                            renderer.ephemeralDragInfo = shape.dragInfo
                            dragState = .dragging
                            break
                        }
                    }
                }
            }
            
            // The dragging is just starting. Let's see what the user is tapping on.
            if let selectedShape = state.selectedShape {
                // There is an existing selected shape. Check if the user is tapping
                // on the same shape, its rotation point or elsewhere.
                if let shape = selectedShape as? PluggableShape,
                   let plug = shape.plugs.first(at: location) {
                    // Inside a plug, so allow the user to drag the plug
                    startDragPlug(plug.id)
                } else if let shape = state.selectedShape as? ConnectableShape,
                          let freeSocket = shape.freeSockets.first(at: location) {
                    // Inside a free socket, so create a new link shape
                    let linkShape = LinkShape(from: .init(shape: shape, socketId: freeSocket.id), to: nil, transition: nil, shapeContext: renderer.shapeContext)
                    linkShape.selected = true
                    provider.append(linkShape)

                    // Delesect the previously selected shape
                    state.selectedShape?.selected = false

                    // Make it the selected shape, including its plug id,
                    // so any subsequent changes in the drag event will drag the plug of that link
                    state.selectedShape = linkShape
                    
                    startDragPlug(linkShape.to.id)
                } else if selectedShape.inside(location) {
                    // Inside the selected shape, let's start dragging it
                    if let shape = selectedShape as? DraggableShape {
                        originalCenter = shape.center
                    }
                    selectedShape.selected = true
                    dragState = .dragging
                } else if let shape = selectedShape as? RotableShape, shape.rotationHandle.contains(location) {
                    // Inside the rotation point of the selected shape, let's rotate
                    originalAngle = shape.rotationAngle
                    deltaRotationAngle = 0
                    dragState = .rotating
                }
            }
            
            if dragState == .none {
                // Let's find out which shape is located at the tap location
                if let selectedShape = provider.shapes.first(where: { $0.inside(location) }) {
                    state.selectedShape = selectedShape
                    provider.shapes.forEach { $0.selected = false }
                    selectedShape.selected = true
                    
                    if let shape = selectedShape as? DraggableShape {
                        originalCenter = shape.center
                    }
                    dragState = .dragging
                } else {
                    // No shape found, deselect everything
                    provider.shapes.forEach { $0.selected = false }
                    state.selectedShape = nil
                    dragState = .ignore
                }
            }
        }
        
        if let shape = state.selectedShape as? RotableShape, dragState == .rotating {
            let rh = shape.rotationPoint
            let center = shape.rotationCenter
            
            let v1 = Vector2D(x: rh.x - center.x, y: rh.y - center.y)
            let v2 = Vector2D(x: location.x - center.x, y: location.y - center.y)
            let angle = v1.angle(to: v2)

            let cross = Vector2D.cross(left: v1, right: v2)
            
            if cross >= 0 {
                deltaRotationAngle += angle
            } else {
                deltaRotationAngle -= angle
            }
            
            // Determine the adjusted rotation angle given the grid specification
            let adjustedRotationAngle = gridAngle(originalAngle + deltaRotationAngle)
            shape.rotationAngle = adjustedRotationAngle

            // Re-compute the deltaRotationAngle so the next time we loop here,
            // its value changes in a smooth way instead of "jumping" around: this is
            // because the shape.rotationPoint uses the rotationAngle and is adjusted as well.
            deltaRotationAngle = adjustedRotationAngle - originalAngle
        } else if let shape = state.selectedShape as? DraggableShape, dragState == .dragging {
            shape.center.x = gridX(originalCenter.x + translation.width)
            shape.center.y = gridY(originalCenter.y + translation.height)
        } else if let shape = state.ephemeralDraggableShape, dragState == .dragging {
            shape.center.x = originalCenter.x + translation.width
            shape.center.y = originalCenter.y + translation.height
        } else if let shape = state.selectedShape as? PluggableShape,
                    let selectedPlugId = selectedPlugId, dragState == .draggingPlug {
            let plug = shape.plugs.first { $0.id == selectedPlugId }
            plug?.socket = findClosestSocket(at: location)
            plug?.freePoint = location
        }

        if let ephemeralDraggableShape = state.ephemeralDraggableShape {
            if let blockShape = ephemeralDraggableShape.droppableShape(provider.blockShapes, at: location) as? BlockShape {
                renderer.ephemeralDragInfo?.dropBlock = blockShape.block
                renderer.ephemeralDragInfo?.dropPath = blockShape.path
            } else {
                renderer.ephemeralDragInfo?.dropBlock = nil
                renderer.ephemeralDragInfo?.dropPath = nil
            }
        }
        
        // Trigger a redraw
        state.triggerRedraw.toggle()
    }
        
    func gridX(_ x: CGFloat) -> CGFloat {
        if state.snapToGrid {
            return round(x / SwitchBoard.GridSize) * SwitchBoard.GridSize
        } else {
            return x
        }
    }
    
    func gridY(_ y: CGFloat) -> CGFloat {
        if state.snapToGrid {
            return round(y / SwitchBoard.GridSize) * SwitchBoard.GridSize
        } else {
            return y
        }
    }

    func gridAngle(_ angle: CGFloat) -> CGFloat {
        if state.snapToGrid {
            let angleGrid: CGFloat = .pi/4
            return round(angle / angleGrid) * angleGrid
        } else {
            return angle
        }
    }
    
    func onDragEnded() {
        if let shape = state.selectedShape as? LinkShape, dragState == .draggingPlug {
            try? SwitchboardLinkUpdater(layout: layout, shapes: provider).updateTransitions(for: shape)
            state.selectedShape = nil
        }
        
        if let trainDragging = renderer.ephemeralDragInfo as? SwitchBoardTrainDragInfo, let dropBlock = trainDragging.dropBlock {
            // Trigger the drop action in the UI
            state.trainDragInfo = .init(trainId: trainDragging.trainId, blockId: dropBlock.id)
            state.trainDroppedInBlockAction.toggle()
        }
        
        state.ephemeralDraggableShape = nil
        renderer.ephemeralDragInfo = nil
        renderer.showAvailableSockets = false
        dragState = .none
        
        layout.didChange()
    }
        
    private func startDragPlug(_ plugId: Int) {
        selectedPlugId = plugId
        dragState = .draggingPlug
        renderer.showAvailableSockets = true
    }
    
    private func findClosestSocket(at location: CGPoint) -> ConnectorSocketInstance? {
        for shape in provider.connectableShapes {
            for socket in shape.freeSockets {
                if socket.shape.contains(location) {
                    return ConnectorSocketInstance(shape: shape, socketId: socket.id)
                }
            }
        }
        return nil
    }
        
}
