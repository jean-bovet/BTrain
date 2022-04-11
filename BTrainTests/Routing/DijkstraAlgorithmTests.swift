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

import XCTest
@testable import BTrain

class DijkstraAlgorithmTests: XCTestCase {

    func testShortestPath() throws {
        let graph = TestGraph()
        
        let n0 = TestNode("0", 0)
        let n1 = TestNode("1", 4)
        let n2 = TestNode("2", 8)
        let n3 = TestNode("3", 7)
        let n4 = TestNode("4", 5)
        let n5 = TestNode("5", 8)
        let n6 = TestNode("6", 1)
        let n7 = TestNode("7", 8)
        let n8 = TestNode("8", 2)

        let links = [
            (n0, n1),
            (n0, n7),
            (n1, n7),
            (n1, n2),
            (n2, n3),
            (n2, n5),
            (n2, n8),
            (n3, n4),
            (n3, n5),
            (n5, n4),
            (n5, n6),
            (n6, n7),
            (n6, n8),
            (n7, n8)
        ]
        
        for (from, to) in links {
            graph.linkNodes(from, to)
        }
        
        for (from, to) in links {
            XCTAssertNotNil(graph.edge(from: from, to: to))
            XCTAssertNotNil(graph.edge(from: to, to: from))
        }
        
        XCTAssertEqual(graph.nodes.count, 9)
        XCTAssertEqual(graph.edges.count, 28)

        let dijkstra = DijkstraAlgorithm(graph: graph)
        let path = dijkstra.shortestPath(from: n0, to: n4).reversed().map { $0.uuid }
        XCTAssertEqual(path, ["0", "7", "6", "5", "4"])
    }

}

final class TestGraph: Graph {
    
    var nodes = [GraphNode]()
    var edges = [GraphEdge]()
    
    func add(_ node: TestNode) {
        if !nodes.contains(where: { $0.identifier.uuid == node.identifier.uuid }) {
            nodes.append(node)
        }
    }
    
    func linkNodes(_ from: TestNode, _ to: TestNode) {
        add(from)
        add(to)
        link(from, to)
        link(to, from)
    }

    private func link(_ from: TestNode, _ to: TestNode) {
        let fromSocketId = from.sockets.count
        let toSocketId = to.sockets.count
        let edge = TestEdge(fromNode: from.identifier, fromNodeSocket: fromSocketId, toNode: to.identifier, toNodeSocket: toSocketId)
        from.sockets.append(fromSocketId)
        to.sockets.append(toSocketId)
        edges.append(edge)
    }

    func edge(from: GraphNode, to: GraphNode) -> GraphEdge? {
        edges.filter({$0.fromNode.uuid == from.identifier.uuid && $0.toNode.uuid == to.identifier.uuid || $0.toNode.uuid == from.identifier.uuid && $0.fromNode.uuid == to.identifier.uuid }).first
    }
    
    func edge(from: GraphNode, socketId: SocketId) -> GraphEdge? {
        edges.filter({$0.fromNode.uuid == from.identifier.uuid && $0.fromNodeSocket == socketId}).first
    }
    
    func node(for identifier: GraphElementIdentifier) -> GraphNode? {
        nodes.filter { $0.identifier.uuid == identifier.uuid }.first
    }
        
}

final class TestNode: GraphNode {
    
    let uuid: String
    
    var identifier: GraphElementIdentifier {
        TestGraphElementIdentifier(uuid: uuid)
    }
    
    var name: String {
        return uuid
    }
    
    var weight: Double = .infinity
    
    var sockets = [SocketId]()
    
    init(_ uuid: String, _ weight: Double) {
        self.uuid = uuid
        self.weight = weight
    }
    
    // Any sockets other than `from` is reachable, which means any edge out of
    // this node is reachable (except the edge identified by `from`).
    func reachableSockets(from socket: SocketId) -> [SocketId] {
        sockets.filter({ $0 != socket })
    }
        
}

struct TestEdge: GraphEdge {
    
    let uuid: String = UUID().uuidString
    
    var identifier: GraphElementIdentifier {
        TestGraphElementIdentifier(uuid: uuid)
    }

    var fromNode: GraphElementIdentifier
    
    var fromNodeSocket: SocketId?
    
    var toNode: GraphElementIdentifier
    
    var toNodeSocket: SocketId?
    
}

struct TestGraphElementIdentifier: GraphElementIdentifier, CustomStringConvertible {
    
    let uuid: String

    var description: String {
        return uuid
    }
}
