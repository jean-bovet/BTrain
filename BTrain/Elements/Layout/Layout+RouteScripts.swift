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

extension NSNotification.Name {
    static let onRoutesUpdated = Notification.Name("onRoutesUpdated")
}

extension Layout {
    @discardableResult
    func newRouteScript() -> RouteScript {
        let script = RouteScript(id: LayoutIdentity.newIdentity(routeScripts.elements, prefix: .routeScript), name: "New Script")
        return routeScripts.add(script)
    }

    @discardableResult
    func duplicate(script: RouteScript) -> RouteScript {
        let newScript = RouteScript(id: LayoutIdentity.newIdentity(routeScripts.elements, prefix: .routeScript), name: "\(script.name) copy")
        newScript.commands = script.commands
        return routeScripts.add(newScript)
    }

    /// Convert all the scripts in the layout into individual routes, updating any existing route.
    ///
    /// Each route unique ID matches the unique ID of the script. When the script is updated, the
    /// same route is going to be updated.
    func updateRoutesUsingRouteScripts() {
        for script in routeScripts.elements {
            if let route = try? script.toRoute() {
                if route.partialSteps.isEmpty {
                    remove(routeId: route.id)
                } else {
                    addOrUpdate(route: route)
                }
            }
        }
        NotificationCenter.default.post(name: .onRoutesUpdated, object: nil)
    }
}
