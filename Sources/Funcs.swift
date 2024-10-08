//  Funcs.swift
//
//  MIT License
//
//  Copyright (c) 2024 straight-tamago, little_34306
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation
import SwiftUI
import UniformTypeIdentifiers

func getOSBuildVersion() -> String {
    var osVersionString = [CChar](repeating: 0, count: 16)
    var size: size_t = osVersionString.count - 1
    let result = sysctlbyname("kern.osversion", &osVersionString, &size, nil, 0)
    
    if result == 0 {
        return String(cString: osVersionString)
    } else {
        return "Unknown"
    }
}

struct Version: Comparable {
    let components: [Int]
    
    init(_ version: String) {
        self.components = version.split(separator: ".").map { Int($0) ?? 0 }
    }
    
    static func < (lhs: Version, rhs: Version) -> Bool {
        let maxLength = max(lhs.components.count, rhs.components.count)
        let paddedLhs = lhs.components + Array(repeating: 0, count: maxLength - lhs.components.count)
        let paddedRhs = rhs.components + Array(repeating: 0, count: maxLength - rhs.components.count)
        return paddedLhs.lexicographicallyPrecedes(paddedRhs)
    }
    
    static func == (lhs: Version, rhs: Version) -> Bool {
        lhs.components == rhs.components
    }
}

extension UIDocumentPickerViewController {
    @objc func fix_init(forOpeningContentTypes contentTypes: [UTType], asCopy: Bool) -> UIDocumentPickerViewController {
        return fix_init(forOpeningContentTypes: contentTypes, asCopy: true)
    }
}

func compareValues(_ value1: Any?, _ value2: Any?) -> Bool {
    if value1 == nil || value2 == nil {
        return false
    }
    switch (value1, value2) {
    case (let int1 as Int, let int2 as Int):
        return int1 == int2
    case (let string1 as String, let string2 as String):
        return string1 == string2
    case (let double1 as Double, let double2 as Double):
        return double1 == double2
    case (let bool1 as Bool, let bool2 as Bool):
        return bool1 == bool2
    case (let array1 as [Any], let array2 as [Any]):
        guard array1.count == array2.count else { return false }
        return zip(array1, array2).allSatisfy { compareValues($0, $1) }
    default:
        return false
    }
}
