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

/// Helper class to fetch configuration information from the Central Station using HTTP requests.
struct MarklinCS3 {
    /// API to retrieve a JSON file containing the definition of all the locomotives
    let API_LOKS = "app/api/loks"

    /// API to retrieve the locomotive icons
    let API_LOKS_ICON = "app/assets/lok"

    /// API to retrieve the function definitions
    let API_FUNCTIONS = "app/api/loks/functionIconGroups"
    private let API_FUNCTIONS_FILE = "app/api/loks:/functionIconGroups"

    /// API to retrieve the function icons
    let API_FUNCTIONS_ICONS = "images/svgSprites/fcticons.json"

    // MARK: - Locomotive
    
    /// The definition of a locomotive
    struct Lok: Decodable {
        let name: String
        let uid: String
        let tachomax: UInt32
        let dectyp: String // mfx+, mm, mfx
        let address: UInt32
        let icon: String
        let funktionen: [LokFunktion]
    }
    
    /// The definition of a locomotive function
    struct LokFunktion: Decodable {
        /*
         {
           "nr": 9,
           "typ": 20,
           "fs": 0,
           "typ2": 20,
           "dauer": 0,
           "state": 0,
           "isMoment": false,
           "icon": "fkticon_i_020"
         },
         */
        let nr: UInt8
        let state: UInt8
        let typ2: UInt32
        let isMoment: Bool
    }
    
    /// Fetches all the locomotives
    /// - Parameter server: the Central Station IP address
    /// - Returns: the array of locomotives
    func fetchLoks(server: URL) async throws -> [Lok] {
        let url = server.appending(path: API_LOKS)
        return try await fetch(url: url)
    }

    /// Fetches the icon for the specified locomotive
    /// - Parameters:
    ///   - server: the Central Station IP address
    ///   - lok: the locomotive
    /// - Returns: the icon data or nil if no icon found
    func fetchLokIcon(server: URL, lok: Lok) async throws -> Data? {
        guard let iconName = iconName(lok: lok) else {
            return nil
        }

        let url = server.appending(path: API_LOKS_ICON).appending(component: iconName)
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }

    private func iconName(lok: Lok) -> String? {
        // /usr/local/cs3/lokicons/SBB 193 524-6 Cargo
        if let name = lok.icon.split(separator: "/").last {
            return String("\(name).png")
        } else {
            return nil
        }
    }
    
    // MARK: - Functions
    
    /// Definition of the group of function
    struct Functions: Decodable {
        let gruppe: [FunctionGroups]
    }
    
    struct FunctionGroups: Decodable {
        let name: String
        let icon: [Function]
    }
    
    struct Function: Decodable {
        //    {
        //      "byte1": "3",
        //      "byte2": "3",
        //      "kurztitel": "Licht",
        //      "type": "1",
        //      "name": "fkticon_a_001",
        //      "typeCompatibility": "1",
        //      "nameCompatibility": "fkticon_a_001"
        //    },
        let kurztitel: String
        let name: String
        let type: String?
        let typeCompatibility: String?
    }

    /// Fetches all the functions
    /// - Parameter server: the Central Station URL
    /// - Returns: the functions
    func fetchFunctions(server: URL) async throws -> Functions {
        let url: URL
        if server.isFileURL {
            // When used in unit test, the local file path must be slighlty different because
            // of a naming conflict on the file system.
            url = server.appending(path: API_FUNCTIONS_FILE)
        } else {
            url = server.appending(path: API_FUNCTIONS)
        }
        return try await fetch(url: url)
    }

    typealias SvgSprites = [String:String]
    
    /// Fetches all the SVG sprites defined in the CS3
    /// - Parameter server: the Central Station URL
    /// - Returns: the SVG sprites
    func fetchSvgSprites(server: URL) async throws -> SvgSprites {
        try await fetch(url: server.appending(path: API_FUNCTIONS_ICONS))
    }

    private func fetch<E:Decodable>(url: URL) async throws -> E {
        BTLogger.network.info("Fetching \(url)")
        let (data, _) = try await URLSession.shared.data(from: url)
        BTLogger.network.info("Got back \(data.count) bytes")
        let functions = try JSONDecoder().decode(E.self, from: data)
        return functions
    }
}
