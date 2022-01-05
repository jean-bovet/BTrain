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

final class LayoutStringParser {
    let ls: String
    var index: String.Index

    var more: Bool {
        return index < ls.endIndex
    }
    
    var c: Character {
        return ls[index]
    }
    
    init(ls: String) {
        self.ls = ls
        self.index = ls.startIndex
    }
    
    func matchesInteger() -> Int? {
        if let n = Int(String(c)) {
            eat()
            return n
        } else {
            return nil
        }
    }
    
    func matches(_ char: Character) -> Bool {
        if c == char {
            eat(char)
            return true
        } else {
            return false
        }
    }
     
    func matches(_ s: String) -> Bool {
        let previousIndex = index
        for expectedC in s {
            if !more {
                // end of string, rewind and return
                index = previousIndex
                return false
            }
            if !matches(expectedC) {
                // mismatch, rewind and return
                index = previousIndex
                return false
            }
        }
        return true
    }

    func matchString(_ endCharacter: Character = " ") -> String {
        return matchString([endCharacter])
    }
    
    func matchString(_ endCharacters: [Character]) -> String {
        var text = ""
        while more && !endCharacters.contains(c) {
            text += String(eat())
        }
        return text
    }
    
    @discardableResult
    func eat(_ expected: Character? = nil) -> Character {
        if let expected = expected {
            assert(c == expected, "Unexpected character \(c), expecting \(expected)")
        }
        let eatenCharater = c
        index = ls.index(after: index)
        return eatenCharater
    }
    
}
