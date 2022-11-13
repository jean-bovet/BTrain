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

extension Layout {
        
    var scripts: [Script] {
        get {
            scriptMap.values.map {
                $0
            }
        }
        set {
            scriptMap.removeAll()
            newValue.forEach { scriptMap[$0.id] = $0 }
        }
    }

    func script(for identifier: Identifier<Script>?) -> Script? {
        if let identifier = identifier {
            return scriptMap[identifier]
        } else {
            return nil
        }
    }
    
    func newScript() -> Script {
        let s = Script()
        addScript(script: s)
        return s
    }
    
    func addScript(script: Script) {
        scriptMap[script.id] = script
    }
    
    func duplicate(scriptId: Identifier<Script>) {
        guard let script = script(for: scriptId) else {
            return
        }
        
        // TODO: should we encode and decode again to ensure full separate object? Same for route and other duplicated object?
        let newScript = newScript()
        newScript.name = "\(script.name) copy"
        newScript.commands = script.commands
    }
    
    func remove(scriptId: Identifier<Script>) {
        scriptMap.removeValue(forKey: scriptId)
    }
    
    func sortScript() {
        scripts.sort {
            $0.name < $1.name
        }
    }
    
    /// Convert all the scripts in the layout into individual routes, updating any existing route.
    ///
    /// Each route unique ID matches the unique ID of the script. When the script is updated, the
    /// same route is going to be updated.
    func convertScriptsToRoute() {
        for script in scripts {
            if let route = try? script.toRoute() {
                if route.partialSteps.isEmpty {
                    remove(routeId: route.id)
                } else {
                    addOrUpdate(route: route)
                }
            }
        }
    }
}
