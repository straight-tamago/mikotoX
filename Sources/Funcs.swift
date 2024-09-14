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

func compareVersion(_ version1: String, _ version2: String) -> Bool {
    let version1Components = version1.split(separator: ".").map { Int($0) ?? 0 }
    let version2Components = version2.split(separator: ".").map { Int($0) ?? 0 }
    
    let maxLength = max(version1Components.count, version2Components.count)
    
    let paddedVersion1 = version1Components + Array(repeating: 0, count: maxLength - version1Components.count)
    let paddedVersion2 = version2Components + Array(repeating: 0, count: maxLength - version2Components.count)
    
    return paddedVersion1.lexicographicallyPrecedes(paddedVersion2) || paddedVersion1 == paddedVersion2
}

extension UIDocumentPickerViewController {
    @objc func fix_init(forOpeningContentTypes contentTypes: [UTType], asCopy: Bool) -> UIDocumentPickerViewController {
        return fix_init(forOpeningContentTypes: contentTypes, asCopy: true)
    }
}
