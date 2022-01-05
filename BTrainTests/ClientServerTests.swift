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

extension Command: Equatable {
    public static func == (lhs: Command, rhs: Command) -> Bool {
        switch(lhs, rhs) {
        case (.go, .go): return true
        case (.stop, .stop): return true
        case (.speed, .speed): return true
        case (.direction, .direction): return true
        case (.queryDirection, .queryDirection): return true
        case (.turnout, .turnout): return true
        case (.feedback, .feedback): return true
        case (.locomotives, .locomotives): return true
        case (.unknown, .unknown): return true
        default:
            return false
        }
    }
}

class ClientServerTests: XCTestCase {

    func testClientWithSimulator() throws {
        let cmd = Command.go()

        let server = Server(port: 15731)
        try server.start()
        
        let serverReceivedMessageExpectation = XCTestExpectation(description: "Received")
        server.didAcceptConnection = { connection in
            connection.receiveMessageCallback = { command in                
                XCTAssertEqual(command, cmd)
                serverReceivedMessageExpectation.fulfill()
            }
        }
        
        let client = Client(host: "localhost", port: 15731)
        let startExpectation = XCTestExpectation(description: "Start")
        client.start {
            startExpectation.fulfill()
        } onData: { data in
            
        } onError: { error in
            XCTAssertNil(error)
        } onStop: {
            
        }
        wait(for: [startExpectation], timeout: 0.250)
        
        let msg = MarklinCANMessage.from(command: cmd)

        client.send(data: msg.data)
        wait(for: [serverReceivedMessageExpectation], timeout: 1.0)
        
        server.stop()
        client.stop()
    }

}
