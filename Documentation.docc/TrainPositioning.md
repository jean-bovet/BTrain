# Train Positioning

This article discusses how a train position is determined and updated.

## Overview

### Train Definition

- A train is composed of one locomotive and zero, one or more cars (also named wagons).
- The head of the train is the part of the train where the locomotive is located. Its position is identified by the "head position".
- The tail of the train is the part of the train where the last car is located. Its position is identified by the "tail position".

                                                                             locomotive      
                                                                             │               
                                                                             │               
                    ◀─────────────────────────cars──────────────────────────▶▼               
              Tail ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■▶ Head          
                    ┌─▶▼                                                 ▼◀─┐                
      Tail Position─┘                                                       └──Head Position 

The head and tail of the train are independent of the direction of travel of the train. In other words, the head
is always the side where the locomotive is located and tail where the last car is located. However, "front" is used
to identify the side of the train that is located towards the direction of travel, and back the opposite.

For example, a train moving forward is represented as:

                            back         front  
      Train Moving Forward: ■■■■■■■■■■■■■■■■■▶  
                            tail          head  
                                                
       Direction of Travel: ─────────────────▶  

For example, a train moving backward is represented as:

                            front         back 
     Train Moving Backward: ■■■■■■■■■■■■■■■■■◀ 
                            tail          head 
                                               
       Direction of Travel: ◀───────────────── 

Notice how tail/head do not change but front/back are dependent on the direction of travel of the train.

### Train Feedbacks

- A train has a way to detect its locomotive (usually by a magnet located under the locomotive that will
  activate a reed feedback). This detection defines the head position.
- Optionally, a train can have a way to detect the last car (in order to move backwards). This
  detection defines the tail position.

### Block Definition

- A block contains one or more feedback identified by an index starting at 0 and growing
  in the natural direction of the block (see Feedback Index in the diagram below).
- A position within the block is identified by an index, growing in the natural direction
  of the block (see Position Index in the diagram below).
- The side of the block that leads to the next block is called the "next" side.
- The side of the block that leads to the previous block is called the "previous" side.
                                                                                
                                        Feedback                                    
                                                                                    
                   Socket                   │                     Socket            
                                            │                                       
                      │                     ▼                        │              
                      │       █             █             █          │              
      Previous        ▼       █             █             █          ▼    Next      
          Side  ──────◉───────█─────────────█─────────────█──────────◉──▶ Side      
                           0  █      1      █      2      █      3                  
                           ▲  █             █             █                         
                           │  0             1             2                         
                           │                ▲                                       
                           │                │                                       
                           │                │                                       
                                                                                    
                    Position Index   Feedback Index                                 


A block has a length and one or more feedback in order to detect a train. Each feedback has a distance
associated with it, starting from the previous side to the next side. The natural direction of the block
is the direction that goes from the previous side to the next side (represented by ``Direction``).

                │◀──────────────────Block Length───────────────▶│            
                │                                               │            
                │        █                 █               █    │            
      Previous  │        █                 █               █    │  Next      
          Side  ─────────█─────────────────█───────────────█────■  Side      
                │        █                 █               █                 
                │        █                 █               █                 
                │                          │                                 
                │                          │                                 
                │     Feedback Distance    │                                 
                └─────────────────────────▶│                                 
                                                                             
                ────────────────────────────────────────────────▶            
                              block natural direction                        
                                                                         
### Train Positions

A train is positioned in the layout by settings its locomotive in a block and "spreading" its cars behind the locomotive, 
possibly overflowing to the previous block if the length of the train is bigger than the block's length.
                                                                                        
        head                         tail              tail                         head        
          ▼                            ▼                 ▼                            ▼         
          0 | 1 | 2      0| 1 | 2     0 | 1 | 2          0 | 1 | 2      0| 1 | 2     0 | 1 | 2  
         ┌─────────┐   ┌─────────┐   ┌─────────┐        ┌─────────┐   ┌─────────┐   ┌─────────┐ 
         │ ▶■■■■■■ │──▶│ ■■■■■■■ │──▶│ ■       │        │ ■■■■■■■ │──▶│ ■■■■■■■ │──▶│ ▶       │ 
         └─────────┘   └─────────┘   └─────────┘        └─────────┘   └─────────┘   └─────────┘ 
           A             B            C                   A             B            C          
                                                                                    
The train is always spread in the opposite direction of travel, starting at the front block all the way to the back block.

For example, a train moving forward will be represented as follow:

                            back         front  
      Train Moving Forward: ■■■■■■■■■■■■■■■■■▶  
                            tail          head  
                                                
       Direction of Travel: ─────────────────▶  
       Direction of Spread: ◀─────────────────  
                                                
For example, a train moving backward will be represented as follow:

                            front         back  
     Train Moving Backward: ■■■■■■■■■■■■■■■■■◀  
                            tail          head  
                                                
       Direction of Travel: ◀─────────────────  
       Direction of Spread: ─────────────────▶  
