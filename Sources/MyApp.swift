//  MyApp.swift
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

class AppState: ObservableObject {
    static var shared = AppState()

    @Published var isShowAlert = false
    @Published var alert: Alert = Alert(title: Text(""), message: Text(""), dismissButton: .default(Text("OK")))

    func showAlert(alertTitle: String, alertMessage: String) {
        DispatchQueue.main.async {
            self.alert = Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            self.isShowAlert = true
        }
    }
}

@main
struct MyApp: App {
    @ObservedObject var appState = AppState.shared

    init() {
        setenv("USBMUXD_SOCKET_ADDRESS", "127.0.0.1:27015", 1)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .alert(isPresented: $appState.isShowAlert) {
                    appState.alert
                }
        }
    }
}
