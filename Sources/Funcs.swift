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
