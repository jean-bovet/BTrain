
**Disclaimer**

BTrain is my attempt at automating a model railway layout. It is open source and free to use but still experimental: use it at your own risk!

![Automatic Routing](/Assets/switchboard.png)

**Concepts**

BTrain uses the following concepts:

- Block: a logical grouping of rails where one and only one train can be present at a time.
- Turnout: an element that guide a train from one rail to another
- Feedback: an element that indicates when a train is present or not
- Transition: any stretch of track between a block and turnout (and any combination of)
- Route: a series of block that a train follows

**Features**

- Support for Markling Central Station 2 & 3
- Automatic discovery of locomotives
- Layout editor
- Locomotives control
- Manual routing
- Automatic routing

**Limitations**

- Does not yet take into account the length of train, blocks and turnouts. This might lead to collision if the train is longer than the block.
- Does not yet take into account true speed conversion. This means the speed of the locomotive is not representative of the prototype model.

**Known Issues**

- The document does not get marked as "Edited" for some changes (probable SwiftUI limitation).

**References**

- [MFX](http://www.skrauss.de/modellbahn/Schienenformat.pdf) (German)
- [Marklin CS2 CAN Protocol version 1.0](https://www.maerklin.de/fileadmin/media/produkte/CS2_can-protokoll_1-0.pdf) (German)
- [Marklin CS2 CAN Protocol version 2.0](https://streaming.maerklin.de/public-media/cs2/cs2CAN-Protokoll-2_0.pdf) (German)
- Thanks to Frans Jacobs for his [open-source project](https://github.com/fransjacobs/model-railway) that inspired me to create the initial command interface to the Central Station.

**Copyrights**

- [Application icon](https://thenounproject.com/icon/train-3130173/) (c) Manaqib S from NounProject.com
- A portion of the application uses [GzipSwift](https://github.com/1024jp/GzipSwift) © 2014-2020 1024jp
- Unit tests use [ViewInspector](https://github.com/nalexn/ViewInspector) by Alexey Naumov
    
**Copyright 2021 Jean Bovet**

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
