# Train Location

This article discusses how a train location is determined and updated.

## Overview

Definitions:
- Front Position: the position of the front of the train, relative to the direction of travel of the train.
- Back Position: the position of the back of the train, relative to the direction of travel of the train.
- A block contains one or more feedback identified by an index starting at 0 and growing
  in the natural direction of the block (see Feedback Index in the diagram below).
- A position within the block is identified by an index, growing in the natural direction
  of the block (see Position Index in the diagram below).
- A train has a way to detect its locomotive (usually a magnet under the locomotive that will
  activate a reed feedback). This detects what we call the "Front Position".
- A train, optionally, has a way to detect the last wagon (in order to move backwards). This
  detects what we call the "Back Position".

                                                                                   F
                     B ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ r
                     a │                 │ │                 │ │                 │ o
                     c │      wagon      │ │      wagon      │ │   locomotive    │ n
                     k │                 │ │                 │ │                 │ t
                       └─────────────────┘ └─────────────────┘ └─────────────────┘
       Back Position ──────────▶  ▼                                       ▼   ◀─────────── Front Position

                               ╲       ██            ██            ██
                                ╲      ██            ██            ██
                         ────────■─────██────────────██────────────██────────────▶
                                ╱   0  ██     1      ██     2      ██     3
                               ╱       ██            ██            ██     ▲
                                       0             1             2      │
                                                     ▲                    │
                                                     │                    │
                                                     │                    │

                                              Feedback Index       Position Index



Let's consider a train moving forward that occupies 3 blocks A, B and C.
The train forward position, identifier by "f", is located under the locomotive
at the front of the train. This position is associated with a magnet under the locomotive that
triggers a feedback each time the locomotive moves over a feedback.

The following diagram shows the train with its front position in (Block C, index 0) and its
back position in (Block A, index 0).

     b                            f
     ▼                            ▼
     0 | 1 | 2      0| 1 | 2     0 | 1 | 2
    ┌─────────┐   ┌─────────┐   ┌─────────┐
    │ ■■■■■■■ │──▶│ ■■■■■■■ │──▶│ ▶       │
    └─────────┘   └─────────┘   └─────────┘
      A             B            C

The following diagram shows the train moving in the direction opposite to the natural direction of block C.
Notice that in this situation, the front position is (Block C, index 2) and back position stays the same.

     b                           f
     ▼                           ▼
     0 | 1 | 2      0| 1 | 2     2 | 1 | 0
    ┌─────────┐   ┌─────────┐   ┌─────────┐
    │ ■■■■■■■ │──▶│ ■■■■■■■ │──▶│ ▶       │
    └─────────┘   └─────────┘   └─────────┘
      A             B            C

The following diagram shows the train moving backwards (that is, the locomotive is pushing the wagons instead of pulling)
with its front position in (Block A, index 0) and back position in (Block C, index 0). By convention, the front
position is always at the "front" of the train when it moves forward and the back position is at the last wagon of the
train when it moves forward.

     f                            b
     ▼                            ▼
     0 | 1 | 2      0| 1 | 2     0 | 1 | 2
    ┌─────────┐   ┌─────────┐   ┌─────────┐
    │ ▶■■■■■■ │──▶│ ■■■■■■■ │──▶│ ■       │
    └─────────┘   └─────────┘   └─────────┘
      A             B            C

The following diagram shows the train moving backwards and entering block C in the direction opposite to the natural direction
of block C. The front position is (Block A, index 0) and back position is (Block C, index 2).

     f                            b
     ▼                            ▼
     0 | 1 | 2      0| 1 | 2     2 | 1 | 0
    ┌─────────┐   ┌─────────┐   ┌─────────┐
    │ ▶■■■■■■ │──▶│ ■■■■■■■ │──▶│ ■       │
    └─────────┘   └─────────┘   └─────────┘
      A             B            C        

TBD describe the train direction.

         Block Natural Direction: ────────▶  ────────▶                    ────────▶  ◀────────            
                                 ┌─────────┐┌─────────┐┌ ─ ─ ─ ─ ┐       ┌─────────┐┌─────────┐┌ ─ ─ ─ ─ ┐
                                 │   b1    ││   b2    │   lead           │   b1    ││   b2    │   lead    
                                 └─────────┘└─────────┘└ ─ ─ ─ ─ ┘       └─────────┘└─────────┘└ ─ ─ ─ ─ ┘
                 Block Positions:  0  1  2    0  1  2                      0  1  2    2  1  0             
                                                                                                          
      Train (direction backward):   ▶■■■■■■■■■■■■■                          ▶■■■■■■■■■■■■■                
               Occupied: [b2, b1]   f            b                          f            b                
        Train Direction In Block: ─ ─ ─ ─ ▶  ─ ─ ─ ─ ▶                    ─ ─ ─ ─ ▶  ─ ─ ─ ─ ▶            
                                                                                                          
      Train (direction backward):   ■■■■■■■■■■■■■◀                          ■■■■■■■■■■■■■◀                
               Occupied: [b1, b2]   b            f                          b            f                
        Train Direction In Block: ◀ ─ ─ ─ ─  ◀ ─ ─ ─ ─                    ◀ ─ ─ ─ ─  ◀ ─ ─ ─ ─            
                                                                                                          
       Train (direction forward):   ■■■■■■■■■■■■■▶                          ■■■■■■■■■■■■■▶                
               Occupied: [b2, b1]   b            f                          b            f                
        Train Direction In Block: ─ ─ ─ ─ ▶  ─ ─ ─ ─ ▶                    ─ ─ ─ ─ ▶  ─ ─ ─ ─ ▶            
                                                                                                          
       Train (direction forward):   ◀■■■■■■■■■■■■■                          ◀■■■■■■■■■■■■■                
               Occupied: [b1, b2]   f            b                          f            b                
        Train Direction In Block: ◀ ─ ─ ─ ─  ◀ ─ ─ ─ ─                    ◀ ─ ─ ─ ─  ◀ ─ ─ ─ ─            

## Topics

### <!--@START_MENU_TOKEN@-->Group<!--@END_MENU_TOKEN@-->

- <!--@START_MENU_TOKEN@-->``Symbol``<!--@END_MENU_TOKEN@-->
