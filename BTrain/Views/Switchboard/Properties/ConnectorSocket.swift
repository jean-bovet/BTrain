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

struct ConnectorSocket {
    let id: Int
    let center: CGPoint
    let controlPoint: CGPoint // Used to help shape the Bezier path connecting to this connector
    let shape: CGPath
    
    static func create(id: Int, center: CGPoint, controlPoint: CGPoint) -> ConnectorSocket {
        let size = 10.0
        let shape = CGPath(ellipseIn: CGRect(x: center.x-size/2, y: center.y-size/2, width: size, height: size), transform: nil)
        return ConnectorSocket(id: id, center: center, controlPoint: controlPoint, shape: shape)
    }

}

struct ConnectorSocketInstance {
    let shape: ConnectableShape
    let socketId: Int
}
