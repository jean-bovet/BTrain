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
    
    /// Returns an array of stations
    var stations: [Station] {
        get {
            return stationMap.values.map { $0 }
        }
        set {
            stationMap.removeAll()
            newValue.forEach { stationMap[$0.id] = $0 }
        }
    }
    
    func newStation() -> Station {
        let station = Station(id: LayoutIdentity.newIdentity(stationMap, prefix: .station), name: "", elements: [])
        stationMap[station.id] = station
        return station
    }
    
    func remove(stationId: Identifier<Station>) {
        stationMap.removeValue(forKey: stationId)
    }
    
    /// Returns the station identified by ``stationId``
    /// - Parameter stationId: the station ID
    /// - Returns: the station or nil if not found
    func station(for stationId: Identifier<Station>?) -> Station? {
        if let stationId = stationId {
            return stationMap[stationId]
        } else {
            return nil
        }
    }

    func sortStations() {
        stations.sort {
            $0.name < $1.name
        }
    }

}
