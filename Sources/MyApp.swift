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

        // let fixMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, Selector("fix_initForOpeningContentTypes:asCopy:"))!
        // let origMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, Selector("initForOpeningContentTypes:asCopy:"))!
        // method_exchangeImplementations(origMethod, fixMethod)
        // let fixMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, #selector(UIDocumentPickerViewController.fix_init(forOpeningContentTypes:asCopy:)))!
        // let origMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, #selector(UIDocumentPickerViewController.init(forOpeningContentTypes:asCopy:)))!
        // method_exchangeImplementations(fixMethod, origMethod)
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
