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

// Supporting reservation of leading blocks when the locomotive is pushing the wagons is a bit more tricky
// because it depends on the configuration of the train and the feedbacks:
// (1) The train only has one feedback under the locomotive
// (2) The train has one feedback under the locomotive and another one at the end of the train under the last wagon.
//
//    ▶■■■■■■  ──▶  ■■■■■■■  ──▶  ■■■■
//    ▲             ▲                ▲
//    │             │                │
//    │             │                │
//    │             │                │
//    Locomotive    Wagon(s)    Head wagon (HW)
//
// - Locomotive position + Length of train = Head wagon position (HWP).
// - Brake train when: HWP is past braking feedback of block it is located in.
// - Stop train when: HWP is past stopping feedback of block it is located in.
// One problem is that because of the lack of feedback in the HW, we can run into problem if the next feedback
// under the locomotive is such that the actual HWP is past the braking or stopping (or even the block altogether)
// position of the block itself.
// Here is an illustration of the movement of train where the locomotive (▶) pushes the wagons (■):
// In this scenario, the HWP is actually activating the braking and stopping feedback of its block at the same
// time as the locomotive does in its block.
//       |   |         |   |         |   |
//    ┌─────────┐   ┌─────────┐   ┌─────────┐
//    │ ▶■■■■■■ │──▶│ ■■■■■■■ │──▶│ ■       │
//    └─────────┘   └─────────┘   └─────────┘
//       |   |         |   |         |   |
//    ┌─────────┐   ┌─────────┐   ┌─────────┐
//    │    ▶■■■ │──▶│ ■■■■■■■ │──▶│ ■■■■    │
//    └─────────┘   └─────────┘   └─────────┘
//       |   |         |   |         |   |
//    ┌─────────┐   ┌─────────┐   ┌─────────┐
//    │        ▶│──▶│ ■■■■■■■ │──▶│ ■■■■■■■■│
//    └─────────┘   └─────────┘   └─────────┘
// However, as described above, this is not always the case. For example:
// In this scenario, when the locomotive triggers the entry/braking feedback of its block,
// the HWP is actually past the stopping feedback of its block. In this situation, the train
// should be stopped.
//       |   |         |   |         |   |
//    ┌─────────┐   ┌─────────┐   ┌─────────┐
//    │ ▶■■■■■■ │──▶│ ■■■■■■■ │──▶│ ■       │
//    └─────────┘   └─────────┘   └─────────┘
//       |   |         |   |         |   |
//    ┌─────────┐   ┌─────────┐   ┌─────────┐
//    │   ▶■■■■ │──▶│ ■■■■■■■ │──▶│ ■■■■■■■ │
//    └─────────┘   └─────────┘   └─────────┘
//
// The pseudo-code to take care of the scenario described above is the following:
// - Each time a feedback is detected by the locomotive, we need to find the next feedback and perform the following evaluations:
//   - If the HWP is past the block it needs to stop in, stop the train.
//   - If the HWP is past the stopping feedback of the block it needs to stop in, stop the train.
//   - If the HWP is past the braking feedback of the block it needs to stop in, brake the train.
extension TrainController {
    
    func handleTrainStopPushingWagons() throws -> Result {
        guard train.speed.kph > 0 else {
            return .none
        }
        
        guard train.wagonsPushedByLocomotive else {
            return .none
        }
                
        // Now determine the position of the head wagon given the next locomotive position
        guard let hwb = try TrainPositionFinder.headWagonBlockFor(train: train, startAtNextPosition: true, layout: layout) else {
            // Stop the train if there is no head wagon block found
            train.state = .stopped
            return try stop(completely: true)
        }
        
        if hwb.reserved != nil && hwb.reserved?.trainId != train.id {
            // Stop the train if the head wagon block is reserved for another train.
            train.state = .stopped
            return try stop(completely: true)
        }
        
        return .none
    }
    
//        let nextFeedback = nextFeedback()
//        let headWagonPositionFeedback = headWagonPositionFeedback()
//        if headWagonPositionFeedback.pastBlock(blockToStopIn) {
//
//        }
//        if headWagonPositionFeedback.isPastBrakingFeedback {
//            // Brake the train
//        }
//        if headWagonPositionFeedback.isPastStoppingFeedback {
//
//        }
  
}
