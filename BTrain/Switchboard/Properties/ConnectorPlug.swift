// Copyright 2021 Jean Bovet
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

final class ConnectorPlug {
    
    let id: Int
        
    var socket: ConnectorSocketInstance?
    var freePoint: CGPoint?
        
    var position: CGPoint {
        if let point = socketPosition() {
            return point
        } else {
            return freePoint ?? .zero
        }
    }
    
    var control: CGPoint {
        if let point = socketControlPoint() {
            return point
        } else {
            return freePoint ?? .zero
        }
    }
    
    var shape: CGPath {
        let size = 10.0
        let shape = CGPath(ellipseIn: CGRect(x: position.x-size/2, y: position.y-size/2, width: size, height: size), transform: nil)
        return shape
    }
    
    func socketControlPoint() -> CGPoint? {
        guard let socket = socket else {
            return nil
        }
        
        return socket.shape.sockets.first(where: { $0.id == socket.socketId })?.controlPoint
    }

    func socketPosition() -> CGPoint? {
        guard let socket = socket else {
            return nil
        }
        
        return socket.shape.sockets.first(where: { $0.id == socket.socketId })?.center
    }

    init(id: Int) {
        self.id = id
    }
        
}
