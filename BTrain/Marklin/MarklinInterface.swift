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

final class MarklinInterface {
        
    let client: Client
    
    let locomotiveConfig = MarklinLocomotiveConfig()
    
    var feedbacks = Set<CommandFeedback>()
    
    // TODO: use direct callback like `directionChangeCallbacks`
    var speedChanges = Set<CommandSpeed>()

    var directionChangeCallbacks = [DirectionChangeCallback]()
    
    typealias CompletionBlock = () -> Void
    
    var locomotivesCommandCompletionBlocks = [QueryLocomotiveCommandCompletion]()
    
    var directionCommandCompletionBlocks = [QueryDirectionCommandCompletion]()
    
    private var disconnectCompletionBlocks: CompletionBlock?
    
    init(server: String, port: UInt16) {
        self.client = Client(host: server, port: port)
    }

    func connect(onReady: @escaping () -> Void, onError: @escaping (Error) -> Void, onUpdate: @escaping () -> Void, onStop: @escaping () -> Void) {
        client.start {
            onReady()
        } onData: { msg in
            if let cmd = MarklinCommand.from(message: msg) {
                switch(cmd) {
                case .direction(address: let address, direction: let direction):
                    self.directionCommandCompletionBlocks.forEach { $0(address, direction) }
                    self.directionCommandCompletionBlocks.removeAll()
                    
                case .configDataStream(length: _, data: _, descriptor: _):
                    let status = self.locomotiveConfig.process(cmd)
                    if case .completed(let locomotives) = status {
                        DispatchQueue.main.async {
                            let locomotives = locomotives.map { $0.commandLocomotive }
                            self.locomotivesCommandCompletionBlocks.forEach { $0(locomotives) }
                            self.locomotivesCommandCompletionBlocks.removeAll()
                        }
                    }
                }
            } else {
                let cmd = Command.from(message: msg)
                if case .feedback(deviceID: let deviceID, contactID: let contactID, oldValue: _, newValue: let newValue, time: _, descriptor: _) = cmd {
                    let fb = CommandFeedback(deviceID: deviceID, contactID: contactID, value: newValue)
                    if !self.feedbacks.insert(fb).inserted {
                        self.feedbacks.update(with: fb)
                    }
                    onUpdate()
                }
                if case .speed(address: let address, speed: let speed, descriptor: _) = cmd {
                    // Receiving a speed change for the specified locomotive address (the protocol is ignored)
                    // TODO: have a background thread for any changes to the layout and layout processing?
                    self.speedChanges.update(with: .init(address: address, speed: speed))
                    onUpdate()
                }
                if case .emergencyStop(address: let address, descriptor: _) = cmd {
                    // NOTE: do not translate the address, the decoder type is ignored here
                    print("Emergency stop \(address.address.toHex())")
                    
                    // Execute a command to query the direction of the locomotive at this particular address
                    DispatchQueue.main.async {
                        self.queryDirection(command: .queryDirection(address: address, descriptor: nil)) { address, direction in
                            self.directionChangeCallbacks.forEach { $0(address, direction) }
                        }
                    }
                }
            }
        } onError: { error in
            onError(error)
        } onStop: {
            DispatchQueue.main.async {
                self.disconnectCompletionBlocks?()
            }
            onStop()
        }
    }

    func disconnect(_ completion: @escaping CompletionBlock) {
        disconnectCompletionBlocks = completion
        client.stop()
    }
    
    func send(message: MarklinCANMessage) {
        client.send(data: message.data)
    }

}

extension MarklinInterface: CommandInterface {    
        
    func register(forDirectionChange callback: @escaping DirectionChangeCallback) {
        directionChangeCallbacks.append(callback)
    }
    
    func execute(command: Command) {
        send(message: MarklinCANMessage.from(command: command))
    }
    
    func queryDirection(command: Command, completion: @escaping QueryDirectionCommandCompletion) {
        directionCommandCompletionBlocks.append(completion)
        execute(command: command)
    }
    
    func queryLocomotives(command: Command, completion: @escaping QueryLocomotiveCommandCompletion) {
        locomotivesCommandCompletionBlocks.append(completion)
        execute(command: command)
    }

}

extension Locomotive {
    
    var commandLocomotive: CommandLocomotive {
        CommandLocomotive(uid: uid, name: name, address: address, decoderType: type?.locomotiveDecoderType)
    }
}

extension String {
    
    var locomotiveDecoderType: DecoderType? {
        switch(self) {
        case "mfx":
            return .MFX
        case "mm_prg":
            return .MM
        case "mm2_prg":
            return .MM2
        case "mm2_dil8":
            return .MM
        case "dcc":
            return .DCC
        case "sx1":
            return .SX1
        default:
            return nil
        }
    }
}
