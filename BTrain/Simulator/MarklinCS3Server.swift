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
import Swifter

/// Simulates the Marklin Central Station HTTP server by servicing http requests such as the locomotive configurations or icons.
final class MarklinCS3Server {
    
    /// There is only one instance of the CS3 server for BTrain
    static let shared = MarklinCS3Server()
        
    private let httpServer = HttpServer()
    
    var running: Bool {
        httpServer.state == .running
    }
    
    /// Contains the URL to the CS3 server files that the simulator is using to respond to the appropriate HTTP commands,
    /// such as the commands to fetch the locomotive configurations or locomotive icons.
    static let cs3ServerDirectory = Bundle.main.url(forResource: "CS3Server", withExtension: nil)!
    
    /// Private initializer to enforce the singleton
    private init() {
        httpServer["/app/assets/lok/:icon"] = { [weak self] request in
            guard let dic = request.params.first(where: { key, value in
                key == ":icon"
            }) else {
                return .notFound
            }
            
            guard let data = self?.lokIconContent(name: dic.value) else {
                return .notFound
            }
            return .ok(.data(data, contentType: "image/png"))
        }

        httpServer["/app/api/loks"] = { [weak self] request in
            if let sSelf = self {
                return .ok(.text(sSelf.loksContent()))
            } else {
                return .ok(.text(""))
            }
        }
    }

    deinit {
        stop()
    }
    
    /// Keep track of the start() and stop() requests and only start or stop
    /// the http server when they reach 0.
    private var startRequests = 0
    
    func start() throws {
        if startRequests == 0 {
            try httpServer.start()
        }
        startRequests += 1
    }
    
    func stop() {
        startRequests -= 1
        if startRequests == 0 {
            httpServer.stop()
        }
    }
    
    private func loksContent() -> String {
        let file = Bundle.main.url(forResource: "loks", withExtension: nil, subdirectory: "CS3Server/app/api")!
        return try! String(contentsOf: file)
    }
    
    private func lokIconContent(name: String) -> Data? {
        let file = MarklinCS3Server.cs3ServerDirectory.appending(components: "app", "assets", "lok", name)
        do {
            return try Data(contentsOf: file)
        } catch {
            BTLogger.error("Locomotive icon not found simulator assets: \(name)")
            return nil
        }
    }

}
