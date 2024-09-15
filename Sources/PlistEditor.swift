//  PlistEditor.swift
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
