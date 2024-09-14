import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State var originalMobileGestalt: URL?
    @State var modifiedMobileGestalt: URL?
    @AppStorage("PairingFile") var pairingFile: String?
    // @State var mobileGestalt: NSMutableDictionary?
    @State var reboot = true
    @State var showPairingFileImporter = false
    @State var showErrorAlert = false
    @State var lastError: String?
    @State var path = NavigationPath()
    @State var isReady = false
    

    @State private var toggles: [String: Bool] = [
        "DynamicIsland2556": false, "DynamicIsland2796": false, "ChargeLimit": false, "BootChime": false,
        "StageManager": false, "DisableShutterSound": false, "AoD": false,
        "AoDVibrancy": false, "ApplePencil": false, "ActionButton": false,
        "InternalStorage": false, "SOSCollision": false, "TapToWake": false,
        "AppleIntelligence": false, "LandScapeFaceID": false, "DisableWallpaperParallax": false,
        "iPadApp": false, "DeveloperMode": false, "CameraControl": false, "SleepApnea": false
    ]

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section {
                    Button {
                        showPairingFileImporter.toggle()
                    } label: {
                        Text("Select pairing file")
                    }
                    .disabled(pairingFile != nil)
                    Button("Reset pairing file") {
                        pairingFile = nil
                    }
                    .disabled(pairingFile == nil)
                } footer: {
                    if pairingFile != nil {
                        Text("Pairing file selected")
                    } else {
                        Text("Select a pairing file to continue")
                    }
                }
                Section {
                    ForEach(toggles.keys.sorted(), id: \.self) { key in
                        Toggle(key, isOn: Binding(get: { toggles[key] ?? false }, set: { toggles[key] = $0 }))
                            .onChange(of: toggles[key]) { _ in processSelectedOptions(key) }
                    }
                }
                Section {
                    Toggle("Reboot after finish restoring", isOn: $reboot)
                    Button("Apply changes") {
                        applyChanges()
                    }
                    .disabled(!isReady)
                    // Text(UIDevice.current.identifierForVendor!.uuidString)
                    Button("Reset changes") {
                        try! FileManager.default.removeItem(at: modifiedMobileGestalt!)
                        try! FileManager.default.removeItem(at: originalMobileGestalt!)
                        // mobileGestalt = try! NSMutableDictionary(contentsOf: modifiedMobileGestalt!, error: ())
                        // applyChanges()
                    }
                    // Button("exportToFile", action: {
                    //     if let plistData = NSDictionary(contentsOfFile: modifiedMobileGestalt!.path) {
                            
                    //         do {
                    //             // PlistをXML形式に変換
                    //             let xmlData = try PropertyListSerialization.data(fromPropertyList: plistData, format: .xml, options: 0)
                                
                    //             // XMLデータをStringに変換
                    //             if let xmlString = String(data: xmlData, encoding: .utf8) {
                                    
                    //                 // クリップボードにコピー
                    //                 UIPasteboard.general.string = xmlString
                                    
                    //                 print("PlistのXMLデータをクリップボードにコピーしました。")
                    //             }
                    //         } catch {
                    //             print("エラー: PlistをXML形式に変換できませんでした。 - \(error)")
                    //         }
                    //     } else {
                    //         print("エラー: Plistファイルを読み込めませんでした。")
                    //     }
                    // })
                } footer: {
                    Text("""
mikotoX: @little_34306 & straight-tamago
A terrible app by @khanhduytran0. Use it at your own risk.
Thanks to:
@SideStore: em_proxy and minimuxer
@JJTech0130: SparseRestore and backup exploit
@PoomSmart: MobileGestalt dump
@libimobiledevice
""")
                }
            }
            .fileImporter(isPresented: $showPairingFileImporter, allowedContentTypes: [UTType(filenameExtension: "mobiledevicepairing", conformingTo: .data)!], onCompletion: { result in
                switch result {
                case .success(let url):
                    guard url.startAccessingSecurityScopedResource() else {
                        return
                    }
                    pairingFile = try! String(contentsOf: url)
                    url.stopAccessingSecurityScopedResource()
                    startMinimuxer()
                case .failure(let error):
                    lastError = error.localizedDescription
                    showErrorAlert.toggle()
                }
            })
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") {}
            } message: {
                Text(lastError ?? "???")
            }
            .navigationDestination(for: String.self) { view in
                if view == "ApplyChanges" {
                    LogView(mgURL: modifiedMobileGestalt!, reboot: reboot)
                }
            }
            .navigationTitle("mikotoX (SparseBox)")
        }
        .onAppear {
            let iOSBuildNumber = ProcessInfo.processInfo.operatingSystemVersionString
            if iOSBuildNumber == "22A3354" {
                toggles["DynamicIsland2622"] = false
                toggles["DynamicIsland2868"] = false
            }
            _ = start_emotional_damage("127.0.0.1:51820")
            if let altPairingFile = Bundle.main.object(forInfoDictionaryKey: "ALTPairingFile") as? String, altPairingFile.count > 5000, pairingFile == nil {
                pairingFile = altPairingFile
            }
            startMinimuxer()

            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            originalMobileGestalt = documentsDirectory.appendingPathComponent("OriginalMobileGestalt.plist", conformingTo: .data)
            modifiedMobileGestalt = documentsDirectory.appendingPathComponent("ModifiedMobileGestalt.plist", conformingTo: .data)
            let url = URL(filePath: "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist")
            if !FileManager.default.fileExists(atPath: originalMobileGestalt!.path) {
                try! FileManager.default.copyItem(at: url, to: originalMobileGestalt!)
            }
            try? FileManager.default.removeItem(atPath: modifiedMobileGestalt!.path)
            try! FileManager.default.copyItem(at: url, to: modifiedMobileGestalt!)
            savePreviousValues()

            
            var timer = Timer()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { (timer) in
                if pairingFile != nil {
                    isReady = ready()
                }
            })
        }
    }

    func applyChanges() {
        if ready() {
            path.append("ApplyChanges")
        } else {
            lastError = "minimuxer is not ready. Ensure you have WiFi and WireGuard VPN set up."
            showErrorAlert.toggle()
        }
    }
    
    func startMinimuxer() {
        guard pairingFile != nil else {
            return
        }
        target_minimuxer_address()
        do {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].absoluteString
            try start(pairingFile!, documentsDirectory)
        } catch {
            lastError = error.localizedDescription
            showErrorAlert.toggle()
        }
    }

    @State private var Previous_isDynamicIsland: Any? = nil
    @State private var Previous_isShutterSound1: Any? = nil
    @State private var Previous_isShutterSound2: Any? = nil

    private func savePreviousValues() {
        self.Previous_isDynamicIsland = PlistEditor.readValue(filePath: self.originalMobileGestalt!.path, keyPath: ["CacheExtra", "oPeik/9e8lQWMszEjbPzng", "ArtworkDeviceSubType"])
        self.Previous_isShutterSound1 = PlistEditor.readValue(filePath: self.originalMobileGestalt!.path, keyPath: ["CacheExtra", "h63QSdBCiT/z0WU6rdQv6Q"])
        self.Previous_isShutterSound2 = PlistEditor.readValue(filePath: self.originalMobileGestalt!.path, keyPath: ["CacheExtra", "zHeENZu+wbg7PUprwNwBWg"])
    }

    private func processSelectedOptions(_ name: String) {
        switch name {
            case "DynamicIsland2556":
                if #available(iOS 16.0, *) {
                    self.toggles["DynamicIsland2796"] = false
                    self.toggles["DynamicIsland2868"] = false
                    self.toggles["DynamicIsland2622"] = false
                    PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "oPeik/9e8lQWMszEjbPzng", "ArtworkDeviceSubType"], value: self.toggles["DynamicIsland2556"]! ? 2556 : self.Previous_isDynamicIsland)
                }
            case "DynamicIsland2796":
                if #available(iOS 16.0, *) {
                    self.toggles["DynamicIsland2556"] = false
                    self.toggles["DynamicIsland2868"] = false
                    self.toggles["DynamicIsland2622"] = false
                    PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "oPeik/9e8lQWMszEjbPzng", "ArtworkDeviceSubType"], value: self.toggles["DynamicIsland2796"]! ? 2796 : self.Previous_isDynamicIsland)
                }
            case "DynamicIsland2622":
                if #available(iOS 19.0, *) {
                    self.toggles["DynamicIsland2556"] = false
                    self.toggles["DynamicIsland2796"] = false
                    self.toggles["DynamicIsland2868"] = false
                    PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "oPeik/9e8lQWMszEjbPzng", "ArtworkDeviceSubType"], value: self.toggles["DynamicIsland2622"]! ? 2622 : self.Previous_isDynamicIsland)
                }
            case "DynamicIsland2868":
                if #available(iOS 19.0, *) {
                    self.toggles["DynamicIsland2556"] = false
                    self.toggles["DynamicIsland2796"] = false
                    self.toggles["DynamicIsland2622"] = false
                    PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "oPeik/9e8lQWMszEjbPzng", "ArtworkDeviceSubType"], value: self.toggles["DynamicIsland2868"]! ? 2868 : self.Previous_isDynamicIsland)
                }
            case "ChargeLimit":
                PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "37NVydb//GP/GrhuTN+exg"], value: self.toggles["ChargeLimit"]! ? 1 : 0)
            case "BootChime":
                PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "QHxt+hGLaBPbQJbXiUJX3w"], value: self.toggles["BootChime"]! ? 1 : 0)
            case "StageManager":
                PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "qeaj75wk3HF4DwQ8qbIi7g"], value: self.toggles["StageManager"]! ? 1 : 0)
            case "DisableShutterSound":
                PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "h63QSdBCiT/z0WU6rdQv6Q"], value: self.toggles["DisableShutterSound"]! ? "US" : self.Previous_isShutterSound1)
                PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "zHeENZu+wbg7PUprwNwBWg"], value: self.toggles["DisableShutterSound"]! ? "LL/A" : self.Previous_isShutterSound2)
            case "AlwaysOnDisplay":
                PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "2OOJf1VhaM7NxfRok3HbWQ"], value: self.toggles["AoD"]! ? 1 : 0)
                PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "j8/Omm6s1lsmTDFsXjsBfA"], value: self.toggles["AoD"]! ? 1 : 0)
            case "AoDVibrancy":
                PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "deviceSupportsAODVibrancy"], value: self.toggles["AoDVibrancy"]! ? 1 : 0)
            case "ApplePencil":
                PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "yhHcB0iH0d1XzPO/CFd3ow"], value: self.toggles["ApplePencil"]! ? 1 : 0)
                PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "nXbrTiBAf1dbo4sCn7xs2w"], value: self.toggles["ApplePencil"]! ? 1 : 0)
            case "ActionButton":
                PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "cT44WE1EohiwRzhsZ8xEsw"], value: self.toggles["ActionButton"]! ? 1 : 0)
            case "InternalStorage":
                PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "LBJfwOEzExRxzlAnSuI7eg"], value: self.toggles["InternalStorage"]! ? 1 : 0)
            case "SOSCollision":
                PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "HCzWusHQwZDea6nNhaKndw"], value: self.toggles["SOSCollision"]! ? 1 : 0)
            case "TapToWake":
                PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "yZf3GTRMGTuwSV/lD7Cagw"], value: self.toggles["TapToWake"]!  ? 1 : 0)
            case "AppleIntelligence":
                PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "A62OafQ85EJAiiqKn4agtg"], value: self.toggles["AppleIntelligence"]! ? 1 : 0)
            case "LandScapeFaceID":
                PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "eP/CPXY0Q1CoIqAWn/J97g"], value: self.toggles["LandScapeFaceID"]! ? 1 : 0)
            case "DisableWallpaperParallax":
                PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "UIParallaxCapability"], value: self.toggles["DisableWallpaperParallax"]! ? 1 : 0)
            case "DeveloperMode":
                PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "EqrsVvjcYDdxHBiQmGhAWw"], value: self.toggles["DeveloperMode"]! ? 1 : 0)
            case "iPadApp":
                if self.toggles["iPadApp"]! {
                    PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "9MZ5AdH43csAUajl/dU+IQ"], value: [1, 2])
                }
            case "CameraControl":
                PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "CwvKxM2cEogD3p+HYgaW0Q"], value: self.toggles["CameraControl"]! ? 1 : 0)
                PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "oOV1jhJbdV3AddkcCg0AEA"], value: self.toggles["CameraControl"]! ? 1 : 0)
            case "SleepApnea":
                PlistEditor.updatePlistValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "e0HV2blYUDBk/MsMEQACNA"], value: self.toggles["SleepApnea"]! ? 1 : 0)
            default:
                break
        }
        // lastError = "AAA \(Previous_isDynamicIsland)"
        // showErrorAlert.toggle()
    }
}

