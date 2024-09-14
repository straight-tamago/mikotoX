//
//  PlistEditor.swift
//  misaka18
//
//  Created by mini on 2024/09/04.
//

import Foundation

class PlistEditor {
    static func updatePlistValue(filePath: String, keyPath: [String], value: Any?) {
        let fileURL = URL(fileURLWithPath: filePath)
        
        guard let plistData = FileManager.default.contents(atPath: fileURL.path) else {
            print("Failed to read plist file")
            return
        }

        let url = URL(filePath: filePath)
        guard let plistDict = try? NSMutableDictionary(contentsOf: url, error: ()) else {
            print("Failed to read plist file")
            return
        }

        update(dictionary: plistDict, keyPath: keyPath, value: value)
        
        do {
            let updatedPlistData = try PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0)
            try updatedPlistData.write(to: fileURL)
            print("Plist file updated successfully")
        } catch {
            print("Failed to write plist file: \(error)")
        }
    }

    static private func update(dictionary: NSMutableDictionary, keyPath: [String], value: Any?) {
        guard !keyPath.isEmpty else { return }

        let key = keyPath[0]
        let remainingPath = Array(keyPath.dropFirst())

        if remainingPath.isEmpty {
            if let value = value {
                dictionary[key] = value
            } else {
                dictionary.removeObject(forKey: key)
            }
        } else {
            if let nestedDict = dictionary[key] as? NSMutableDictionary {
                update(dictionary: nestedDict, keyPath: remainingPath, value: value)
                dictionary[key] = nestedDict
            } else {
                let nestedDict = NSMutableDictionary()
                update(dictionary: nestedDict, keyPath: remainingPath, value: value)
                dictionary[key] = nestedDict
            }
        }
    }
    
    static func readValue(filePath: String, keyPath: [String]) -> Any? {
        let fileURL = URL(fileURLWithPath: filePath)
        
        guard let plistData = FileManager.default.contents(atPath: fileURL.path) else {
            print("Failed to read plist file")
            return "A"
        }

        let url = URL(filePath: filePath)
        guard let plistDict = try? NSMutableDictionary(contentsOf: url, error: ()) else {
            print("Failed to read plist file")
            return "B"
        }

        return read(dictionary: plistDict, keyPath: keyPath)
    }

    static private func read(dictionary: NSDictionary, keyPath: [String]) -> Any? {
        guard !keyPath.isEmpty else { return nil }

        let key = keyPath[0]
        let remainingPath = Array(keyPath.dropFirst())

        if remainingPath.isEmpty {
            return dictionary[key]
        } else {
            if let nestedDict = dictionary[key] as? NSDictionary {
                return read(dictionary: nestedDict, keyPath: remainingPath)
            } else {
                return nil
            }
        }
    }
}
