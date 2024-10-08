//  LogView.swift
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

import SwiftUI

let logPipe = Pipe()

struct RestoreFileST {
    var from: URL
    var to: URL
}

class SparceBox: ObservableObject {
    static var shared = SparceBox()
    @Published var udid: String = ""
    @Published var restoreFiles: [RestoreFileST] = []
    @Published var reboot: Bool = true
    @Published var log: String = ""
    @Published var isRebooting = false
    
    func doRestore() {
        let deviceList = MobileDevice.deviceList()
        guard deviceList.count == 1 else {
            print("Invalid device count: \(deviceList.count)")
            self.udid = "invalid"
            return
        }
        self.udid = deviceList.first!

        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = documentsDirectory.appendingPathComponent(udid, conformingTo: .data)
        
        do {
            try? FileManager.default.removeItem(at: folder)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            
            let mbdb = createBackupFile()
            try mbdb.writeTo(directory: folder)
            
            let restoreArgs = [
                "idevicebackup2",
                "-n", "restore", "--no-reboot", "--system",
                documentsDirectory.path(percentEncoded: false)
            ]
            print("Executing args: \(restoreArgs)")
            var argv = restoreArgs.map{ strdup($0) }

            let result = idevicebackup2_main(Int32(restoreArgs.count), &argv)
            print("idevicebackup2 exited with code \(result)")

            guard log.contains("crash_on_purpose") else { return }
            print("Restore succeeded")
            
            if reboot {
                isRebooting.toggle()
                MobileDevice.rebootDevice(udid: udid)
            }
            
            logPipe.fileHandleForReading.readabilityHandler = nil
        } catch {
            print(error.localizedDescription)
            return
        }
    }

    func createBackupFile() -> Backup {
        var files: [ConcreteFile] = []

        for restoreFile in restoreFiles {
            let contents = try! Data(contentsOf: restoreFile.from)
            // required on iOS 17.0+ since /var/mobile is on a separate partition
            let basePath = restoreFile.to.path(percentEncoded: false).hasPrefix("/var/mobile/") ? "/var/mobile/backup" : "/var/backup"

            files.append(
                ConcreteFile(path: "", domain: "SysContainerDomain-../../../../../../../..\(restoreFile.to.path(percentEncoded: false))", contents: contents, owner: 501, group: 501)
            )
            files.append(
                ConcreteFile(path: "", domain: "SysContainerDomain-../../../../../../../../crash_on_purpose", contents: Data())
            )
        }

        return Backup(files: files)
    }
}

struct SparceBoxLogView: View {
    @ObservedObject var sparceBox = SparceBox.shared
    @State var ran = false

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(sparceBox.log)
                        .font(.system(size: 12).monospaced())
                        .fixedSize(horizontal: false, vertical: false)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                        .id(0)
                }
                .onAppear {
                    guard !ran else { return }
                    ran = true
                    
                    logPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                        let data = fileHandle.availableData
                        if !data.isEmpty, var logString = String(data: data, encoding: .utf8) {
                            if logString.contains(sparceBox.udid) {
                                logString = logString.replacingOccurrences(of: sparceBox.udid, with: "<redacted>")
                            }
                            sparceBox.log.append(logString)
                            proxy.scrollTo(0)
                        }
                    }

                    DispatchQueue.global(qos: .background).async {
                        sparceBox.doRestore()
                    }
                }
            }
        }
        .navigationTitle(sparceBox.isRebooting ? "Rebooting device" : "Log output")
        .navigationViewStyle(.stack)
    }
    
    init() {
        setvbuf(stdout, nil, _IOLBF, 0) // make stdout line-buffered
        setvbuf(stderr, nil, _IONBF, 0) // make stderr unbuffered
        
        // create the pipe and redirect stdout and stderr
        dup2(logPipe.fileHandleForWriting.fileDescriptor, fileno(stdout))
        dup2(logPipe.fileHandleForWriting.fileDescriptor, fileno(stderr))
    }
}
