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

final class LayoutObserverTests: XCTestCase {

    func testTrains() async {
        let layout = Layout()
        let lo = LayoutObserver(layout: layout)
        let t1 = Train(id: .init(uuid: "id_1"), name: "ID_1")

        let registerBlock: RegisterBlock = { callback in
            lo.registerForTrainChange { trains in
                callback(trains)
            }
        }
        
        let unregister: UnregisterBlock = {
            lo.unregisterAll()
        }

        await assertChange(expected: [t1], operation: { layout.trains.add(t1) }, register: registerBlock, unregister: unregister)
        await assertChange(expected: [], operation: { layout.trains.remove(t1.id) }, register: registerBlock, unregister: unregister)
        await assertChange(expected: [t1], operation: { layout.trains.elements.append(t1) }, register: registerBlock, unregister: unregister)
        await assertChange(expected: [], operation: { layout.trains.elements.removeFirst() }, register: registerBlock, unregister: unregister)
    }

    func testBlocks() async {
        let layout = Layout()
        let lo = LayoutObserver(layout: layout)
        let b1 = Block(name: "b1")
        
        let registerBlock: RegisterBlock = { callback in
            lo.registerForBlockChange { blocks in
                callback(blocks)
            }
        }
        
        let unregister: UnregisterBlock = {
            lo.unregisterAll()
        }

        await assertChange(expected: [b1], operation: { layout.blocks.add(b1) }, register: registerBlock, unregister: unregister)
        await assertChange(expected: [], operation: { layout.blocks.remove(b1.id) }, register: registerBlock, unregister: unregister)
        await assertChange(expected: [b1], operation: { layout.blocks.elements.append(b1) }, register: registerBlock, unregister: unregister)
        await assertChange(expected: [], operation: { layout.blocks.elements.removeFirst() }, register: registerBlock, unregister: unregister)
    }

    func testTurnouts() async {
        let layout = Layout()
        let lo = LayoutObserver(layout: layout)
        let t1 = Turnout(name: "T_1")

        let registerBlock: RegisterBlock = { callback in
            lo.registerForTurnoutChange { turnouts in
                callback(turnouts)
            }
        }
        
        let unregister: UnregisterBlock = {
            lo.unregisterAll()
        }

        await assertChange(expected: [t1], operation: { layout.turnouts.add(t1) }, register: registerBlock, unregister: unregister)
        await assertChange(expected: [], operation: { layout.turnouts.remove(t1.id) }, register: registerBlock, unregister: unregister)
        await assertChange(expected: [t1], operation: { layout.turnouts.elements.append(t1) }, register: registerBlock, unregister: unregister)
        await assertChange(expected: [], operation: { layout.turnouts.elements.removeFirst() }, register: registerBlock, unregister: unregister)
    }

    func testTransitions() async {
        let layout = Layout()
        let lo = LayoutObserver(layout: layout)
        let t1 = Transition(id: .init(uuid: "t1"), a: .block(.init(uuid: "b1")), b: .block(.init(uuid: "b2")))

        let registerBlock: RegisterBlock = { callback in
            lo.registerForTransitionChange { transitions in
                callback(transitions)
            }
        }
        
        let unregister: UnregisterBlock = {
            lo.unregisterAll()
        }

        await assertChange(expected: [t1], operation: { layout.transitions.add(t1) }, register: registerBlock, unregister: unregister)
        await assertChange(expected: [], operation: { layout.transitions.remove(t1.id) }, register: registerBlock, unregister: unregister)
        await assertChange(expected: [t1], operation: { layout.transitions.elements.append(t1) }, register: registerBlock, unregister: unregister)
        await assertChange(expected: [], operation: { layout.transitions.elements.removeFirst() }, register: registerBlock, unregister: unregister)
    }

    typealias RegisterBlock<E> = (@escaping ([E]) -> Void) -> Void
    typealias UnregisterBlock = () -> Void
    
    private func assertChange<E:Element>(expected: [E], operation: CompletionBlock, register: RegisterBlock<E>, unregister: UnregisterBlock) async {
        let elements = await assertChange(operation: operation, register: register)
        XCTAssertEqual(elements, expected)
        unregister()
    }

    private func assertChange<E>(operation: CompletionBlock, register: RegisterBlock<E>) async -> [E] {
        return await withCheckedContinuation { continuation in
            register() { elements in
                continuation.resume(returning: (elements))
            }
            operation()
        }
    }

    func assertChanged<E:Element>(layout: Layout, expected: [[E]], operations: [CompletionBlock], register: @escaping (@escaping ([E]) -> Void) -> Void) {
        for (index, operation) in operations.enumerated() {
            let e = expectation(description: "e")
            register() { elements in
                XCTAssertEqual(elements, expected[index])
                e.fulfill()
            }
            operation()
            waitForExpectations(timeout: 0.5)
        }
    }
    
}
