import SwiftUI
import UniformTypeIdentifiers

struct ToggleST {
    var label: String
    var value: [ToggleValueST]
    var isOn: Bool = false
    var isDisabled = false
}

struct ToggleValueST {
    var keyPath: [String]
    var enabled: Any?
    var disabled: Any?
}

struct ContentView: View {
    let currentAppVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    @ObservedObject var appState = AppState.shared
    @ObservedObject var sparceBox = SparceBox.shared

    @State var showPairingFileImporter = false
    @AppStorage("PairingFile") var pairingFile: String?
    @State var originalMobileGestalt: URL?
    @State var modifiedMobileGestalt: URL?
    
    @State var path = NavigationPath()
    @State var reboot = true
    @State var isReady = false

    @State var showCustomFilePicker = false
    @State var selectedFile: URL?
    @State var customFilePath: String = ""
    @State var isCustomPathEnabled = false
    @State private var isPathValid: Bool = true

    @State private var toggles: [ToggleST] = []
    
    func startMinimuxer() {
        guard pairingFile != nil else { return }
        target_minimuxer_address()
        do {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].absoluteString
            try start(pairingFile!, documentsDirectory)
        } catch {
            appState.showAlert(alertTitle: "Error", alertMessage: error.localizedDescription)
        }
    }

    func applyChanges() {
        if ready() {
            sparceBox.reboot = reboot
            sparceBox.restoreFiles = [
                RestoreFileST(
                    from: modifiedMobileGestalt!,
                    to: URL(fileURLWithPath: "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist")
                )
            ]
            path.append("ApplyChanges")
        } else {
            appState.showAlert(alertTitle: "Error", alertMessage: "minimuxer is not ready. Ensure you have WiFi and WireGuard VPN set up.")
        }
    }

    init() {
        let fixMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, Selector("fix_initForOpeningContentTypes:asCopy:"))!
        let origMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, Selector("initForOpeningContentTypes:asCopy:"))!
        method_exchangeImplementations(origMethod, fixMethod)
    }

    func isPathValid(_ path: String) -> Bool {
        let blockedPaths = ["/var/containers", "/var/preferences"]
        for blockedPath in blockedPaths {
            if path.hasPrefix(blockedPath) {
                return true
            }
        }
        return false
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Button(pairingFile == nil ? "Select pairing file" : "Reset pairing file") {
                        if pairingFile == nil {
                            showPairingFileImporter.toggle()
                        } else {
                            pairingFile = nil
                        }
                    }
                    .dropDestination(for: Data.self) { items, location in
                        guard let item = items.first else { return false }
                        pairingFile = try! String(decoding: item, as: UTF8.self)
                        guard pairingFile?.contains("DeviceCertificate") ?? false else {
                            appState.showAlert(alertTitle: "Error", alertMessage: "The file you just dropped is not a pairing file")
                            pairingFile = nil
                            return false
                        }
                        startMinimuxer()
                        return true
                    }
                } footer: {
                    if pairingFile != nil {
                        Text("Pairing file selected")
                    } else {
                        Text("Select or drag and drop a pairing file to continue. More info: https://docs.sidestore.io/docs/getting-started/pairing-file")
                    }
                }
                .fileImporter(isPresented: $showPairingFileImporter, allowedContentTypes: [UTType(filenameExtension: "mobiledevicepairing", conformingTo: .data)!], onCompletion: { result in
                    switch result {
                    case .success(let url):
                        pairingFile = try! String(contentsOf: url)
                        startMinimuxer()
                    case .failure(let error):
                        appState.showAlert(alertTitle: "Error", alertMessage: error.localizedDescription)
                    }
                })

                Section {
                    Toggle("Enable Custom Path", isOn: $isCustomPathEnabled)
                    
                    if isCustomPathEnabled {
                        Button("Select custom file") {
                            showCustomFilePicker.toggle()
                        }
                        
                        if let selectedFile = selectedFile {
                            Text("Selected file: \(selectedFile.lastPathComponent)")
                        }
                        
                        TextField("Enter destination path", text: $customFilePath)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: customFilePath) { newValue in
                                isPathValid = isPathValid(newValue)
                            }
                        
                        if !isPathValid {
                            Text("Invalid path. Access to this directory is blocked.")
                                .foregroundColor(.red)
                        }

                        Button("Start Restore") {
                            if let from = selectedFile {
                                let to = URL(fileURLWithPath: customFilePath)

                                sparceBox.reboot = reboot
                                sparceBox.restoreFiles = [
                                    RestoreFileST(
                                        from: from,
                                        to: to
                                    )
                                ]
                                path.append("ApplyChanges")
                            }
                        }
                        .disabled(selectedFile == nil || customFilePath.isEmpty || !isPathValid)
                        .disabled(!isReady)
                    }
                }
                .fileImporter(isPresented: $showCustomFilePicker, allowedContentTypes: [UTType.data], onCompletion: { result in
                    switch result {
                    case .success(let url):
                        selectedFile = url
                    case .failure(let error):
                        appState.showAlert(alertTitle: "Error", alertMessage: error.localizedDescription)
                    }
                })

                Section {
                    ForEach($toggles.indices, id: \.self) { index in
                        Toggle(isOn: $toggles[index].isOn) {
                            Text(toggles[index].label)
                        }
                        .onChange(of: toggles[index].isOn) { isOn in
                            for value in toggles[index].value {
                                PlistEditor.updatePlistValue(
                                    filePath: modifiedMobileGestalt!.path, 
                                    keyPath: value.keyPath, 
                                    value: isOn ? value.enabled : value.disabled
                                )
                            }
                        }
                        .disabled(toggles[index].isDisabled)
                    }
                }

                Section {
                    Toggle("Reboot after finish restoring", isOn: $reboot)
                    
                    Button("Apply changes") {
                        applyChanges()
                    }
                    .disabled(!isReady)

                    Button("Reset changes") {
                        try! FileManager.default.removeItem(at: modifiedMobileGestalt!)
                        try! FileManager.default.copyItem(at: originalMobileGestalt!, to: modifiedMobileGestalt!)
                    }
                } footer: {
                    Text("""
mikotoX: @little_34306 & straight-tamago
An incredible app by @khanhduytran0. Use it at your own risk.
Thanks to:
@SideStore: em_proxy and minimuxer
@JJTech0130: SparseRestore and backup exploit
@PoomSmart: MobileGestalt dump
@libimobiledevice
""")
                }
            }
            .navigationTitle("mikotoX (SparseBox)")
            .navigationDestination(for: String.self) { view in
                if view == "ApplyChanges" {
                    SparceBoxLogView()
                }
            }
        }
        .onAppear {
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
                try! FileManager.default.copyItem(at: url, to: modifiedMobileGestalt!)
            }
            
            let _ = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { (timer) in
                if pairingFile != nil && !isReady {
                    isReady = ready()
                }
            })

            addComponents()
        }
    }
    
    func addComponents() { 
        toggles = [
            ToggleST(
                label: "Dynamic Island (17.4+ method) (2556)",
                value: [
                    ToggleValueST(
                        keyPath: ["CacheExtra", "oPeik/9e8lQWMszEjbPzng", "ArtworkDeviceSubType"],
                        enabled: 2556,
                        disabled: PlistEditor.readValue(filePath: self.originalMobileGestalt!.path, keyPath: ["CacheExtra", "oPeik/9e8lQWMszEjbPzng", "ArtworkDeviceSubType"]) as Any
                    )
                ],
                isOn: compareValues(
                    PlistEditor.readValue(filePath: self.originalMobileGestalt!.path, keyPath: ["CacheExtra", "oPeik/9e8lQWMszEjbPzng", "ArtworkDeviceSubType"]), 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "oPeik/9e8lQWMszEjbPzng", "ArtworkDeviceSubType"])
                ),
                isDisabled: Version(UIDevice.current.systemVersion) < Version("16.0")
            ),
            ToggleST(
                label: "Dynamic Island (17.4+ method) (2796)",
                value: [
                    ToggleValueST(
                        keyPath: ["CacheExtra", "oPeik/9e8lQWMszEjbPzng", "ArtworkDeviceSubType"],
                        enabled: 2796,
                        disabled: PlistEditor.readValue(filePath: self.originalMobileGestalt!.path, keyPath: ["CacheExtra", "oPeik/9e8lQWMszEjbPzng", "ArtworkDeviceSubType"]) as Any
                    )
                ],
                isOn: compareValues(
                    PlistEditor.readValue(filePath: self.originalMobileGestalt!.path, keyPath: ["CacheExtra", "oPeik/9e8lQWMszEjbPzng", "ArtworkDeviceSubType"]), 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "oPeik/9e8lQWMszEjbPzng", "ArtworkDeviceSubType"])
                ),
                isDisabled: Version(UIDevice.current.systemVersion) < Version("16.0")
            ),
            ToggleST(
                label: "Dynamic Island (17.4+ method) (2622)",
                value: [
                    ToggleValueST(
                        keyPath: ["CacheExtra", "oPeik/9e8lQWMszEjbPzng", "ArtworkDeviceSubType"],
                        enabled: 2622,
                        disabled: PlistEditor.readValue(filePath: self.originalMobileGestalt!.path, keyPath: ["CacheExtra", "oPeik/9e8lQWMszEjbPzng", "ArtworkDeviceSubType"]) as Any
                    )
                ],
                isOn: compareValues(
                    PlistEditor.readValue(filePath: self.originalMobileGestalt!.path, keyPath: ["CacheExtra", "oPeik/9e8lQWMszEjbPzng", "ArtworkDeviceSubType"]), 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "oPeik/9e8lQWMszEjbPzng", "ArtworkDeviceSubType"])
                ),
                isDisabled: getOSBuildVersion() != "22A3354"
            ),
            ToggleST(
                label: "Dynamic Island (17.4+ method) (2868)",
                value: [
                    ToggleValueST(
                        keyPath: ["CacheExtra", "oPeik/9e8lQWMszEjbPzng", "ArtworkDeviceSubType"],
                        enabled: 2868,
                        disabled: PlistEditor.readValue(filePath: self.originalMobileGestalt!.path, keyPath: ["CacheExtra", "oPeik/9e8lQWMszEjbPzng", "ArtworkDeviceSubType"]) as Any
                    )
                ],
                isOn: compareValues(
                    PlistEditor.readValue(filePath: self.originalMobileGestalt!.path, keyPath: ["CacheExtra", "oPeik/9e8lQWMszEjbPzng", "ArtworkDeviceSubType"]), 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "oPeik/9e8lQWMszEjbPzng", "ArtworkDeviceSubType"])
                ),
                isDisabled: getOSBuildVersion() != "22A3354"
            ),
            ToggleST(
                label: "Charge Limit",
                value: [
                    ToggleValueST(
                        keyPath: ["CacheExtra", "37NVydb//GP/GrhuTN+exg"],
                        enabled: 1,
                        disabled: 0
                    )
                ],
                isOn: compareValues(
                    1, 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "37NVydb//GP/GrhuTN+exg"])
                ),
                isDisabled: Version(UIDevice.current.systemVersion) < Version("17.0")
            ),
            ToggleST(
                label: "Boot Chime",
                value: [
                    ToggleValueST(
                        keyPath: ["CacheExtra", "QHxt+hGLaBPbQJbXiUJX3w"],
                        enabled: 1,
                        disabled: 0
                    )
                ],
                isOn: compareValues(
                    1, 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "QHxt+hGLaBPbQJbXiUJX3w"])
                )
            ),
            ToggleST(
                label: "Stage Manager",
                value: [
                    ToggleValueST(
                        keyPath: ["CacheExtra", "qeaj75wk3HF4DwQ8qbIi7g"],
                        enabled: 1,
                        disabled: 0
                    )
                ],
                isOn: compareValues(
                    1, 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "qeaj75wk3HF4DwQ8qbIi7g"])
                ),
                isDisabled: Version(UIDevice.current.systemVersion) < Version("16.0")
            ),
            ToggleST(
                label: "Disable Shutter Sound",
                value: [
                    ToggleValueST(
                        keyPath: ["CacheExtra", "h63QSdBCiT/z0WU6rdQv6Q"],
                        enabled: "US",
                        disabled: PlistEditor.readValue(filePath: self.originalMobileGestalt!.path, keyPath: ["CacheExtra", "h63QSdBCiT/z0WU6rdQv6Q"]) as Any
                    ),
                    ToggleValueST(
                        keyPath: ["CacheExtra", "zHeENZu+wbg7PUprwNwBWg"],
                        enabled: "LL/A",
                        disabled: PlistEditor.readValue(filePath: self.originalMobileGestalt!.path, keyPath: ["CacheExtra", "zHeENZu+wbg7PUprwNwBWg"]) as Any
                    ),
                ],
                isOn: compareValues(
                    PlistEditor.readValue(filePath: self.originalMobileGestalt!.path, keyPath: ["CacheExtra", "h63QSdBCiT/z0WU6rdQv6Q"]), 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "h63QSdBCiT/z0WU6rdQv6Q"])
                ) && compareValues(
                    PlistEditor.readValue(filePath: self.originalMobileGestalt!.path, keyPath: ["CacheExtra", "zHeENZu+wbg7PUprwNwBWg"]), 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "zHeENZu+wbg7PUprwNwBWg"])
                )
            ),
            ToggleST(
                label: "Always on Display (18.0+)",
                value: [
                    ToggleValueST(
                        keyPath: ["CacheExtra", "2OOJf1VhaM7NxfRok3HbWQ"],
                        enabled: 1,
                        disabled: 0
                    ),
                    ToggleValueST(
                        keyPath: ["CacheExtra", "j8/Omm6s1lsmTDFsXjsBfA"],
                        enabled: 1,
                        disabled: 0
                    ),
                ],
                isOn: compareValues(
                    1, 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "2OOJf1VhaM7NxfRok3HbWQ"])
                ) && compareValues(
                    1, 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "j8/Omm6s1lsmTDFsXjsBfA"])
                ),
                isDisabled: Version(UIDevice.current.systemVersion) < Version("18.0")
            ),
            ToggleST(
                label: "Apple Pencil",
                value: [
                    ToggleValueST(
                        keyPath: ["CacheExtra", "yhHcB0iH0d1XzPO/CFd3ow"],
                        enabled: 1,
                        disabled: 0
                    ),
                    ToggleValueST(
                        keyPath: ["CacheExtra", "nXbrTiBAf1dbo4sCn7xs2w"],
                        enabled: 1,
                        disabled: 0
                    ),
                ],
                isOn: compareValues(
                    1, 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "yhHcB0iH0d1XzPO/CFd3ow"])
                ) && compareValues(
                    1, 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "nXbrTiBAf1dbo4sCn7xs2w"])
                )
            ),
            ToggleST(
                label: "Action Button",
                value: [
                    ToggleValueST(
                        keyPath: ["CacheExtra", "cT44WE1EohiwRzhsZ8xEsw"],
                        enabled: 1,
                        disabled: 0
                    )
                ],
                isOn: compareValues(
                    1, 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "cT44WE1EohiwRzhsZ8xEsw"])
                ),
                isDisabled: Version(UIDevice.current.systemVersion) < Version("17.0")
            ),
            ToggleST(
                label: "Internal Storage",
                value: [
                    ToggleValueST(
                        keyPath: ["CacheExtra", "LBJfwOEzExRxzlAnSuI7eg"],
                        enabled: 1,
                        disabled: 0
                    )
                ],
                isOn: compareValues(
                    1, 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "LBJfwOEzExRxzlAnSuI7eg"])
                )
            ),
            ToggleST(
                label: "Tap to Wake (iPhone SE)",
                value: [
                    ToggleValueST(
                        keyPath: ["CacheExtra", "yZf3GTRMGTuwSV/lD7Cagw"],
                        enabled: 1,
                        disabled: 0
                    )
                ],
                isOn: compareValues(
                    1, 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "yZf3GTRMGTuwSV/lD7Cagw"])
                ),
                isDisabled: UIDevice.perform(Selector(("_hasHomeButton"))) == nil
            ),
            ToggleST(
                label: "SOS Collision",
                value: [
                    ToggleValueST(
                        keyPath: ["CacheExtra", "HCzWusHQwZDea6nNhaKndw"],
                        enabled: 1,
                        disabled: 0
                    )
                ],
                isOn: compareValues(
                    1, 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "HCzWusHQwZDea6nNhaKndw"])
                ),
                isDisabled: Version(UIDevice.current.systemVersion) < Version("16.0")
            ),
            ToggleST(
                label: "Apple Intelligence",
                value: [
                    ToggleValueST(
                        keyPath: ["CacheExtra", "A62OafQ85EJAiiqKn4agtg"],
                        enabled: 1,
                        disabled: 0
                    )
                ],
                isOn: compareValues(
                    1, 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "A62OafQ85EJAiiqKn4agtg"])
                ),
                isDisabled: Version(UIDevice.current.systemVersion) < Version("18.1")
            ),
            ToggleST(
                label: "LandScape FaceID",
                value: [
                    ToggleValueST(
                        keyPath: ["CacheExtra", "eP/CPXY0Q1CoIqAWn/J97g"],
                        enabled: 1,
                        disabled: 0
                    )
                ],
                isOn: compareValues(
                    1, 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "eP/CPXY0Q1CoIqAWn/J97g"])
                )
            ),
            ToggleST(
                label: "Disable Wallpaper Parallax",
                value: [
                    ToggleValueST(
                        keyPath: ["CacheExtra", "UIParallaxCapability"],
                        enabled: 1,
                        disabled: 0
                    )
                ],
                isOn: compareValues(
                    1, 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "UIParallaxCapability"])
                )
            ),
            ToggleST(
                label: "Allow installing iPadOS apps",
                value: [
                    ToggleValueST(
                        keyPath: ["CacheExtra", "9MZ5AdH43csAUajl/dU+IQ"],
                        enabled: [1, 2],
                        disabled: [1, 2]
                    )
                ],
                isOn: compareValues(
                    [1, 2], 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "9MZ5AdH43csAUajl/dU+IQ"])
                ),
                isDisabled: UIDevice.current.userInterfaceIdiom != .pad
            ),
            ToggleST(
                label: "Developer Mode (Metal HUD)",
                value: [
                    ToggleValueST(
                        keyPath: ["CacheExtra", "EqrsVvjcYDdxHBiQmGhAWw"],
                        enabled: 1,
                        disabled: 0
                    )
                ],
                isOn: compareValues(
                    1, 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "EqrsVvjcYDdxHBiQmGhAWw"])
                )
            ),
            ToggleST(
                label: "Camera Control",
                value: [
                    ToggleValueST(
                        keyPath: ["CacheExtra", "CwvKxM2cEogD3p+HYgaW0Q"],
                        enabled: 1,
                        disabled: 0
                    )
                ],
                isOn: compareValues(
                    1, 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "CwvKxM2cEogD3p+HYgaW0Q"])
                ),
                isDisabled: Version(UIDevice.current.systemVersion) < Version("18.0")
            ),
            ToggleST(
                label: "Sleep Apnea",
                value: [
                    ToggleValueST(
                        keyPath: ["CacheExtra", "e0HV2blYUDBk/MsMEQACNA"],
                        enabled: 1,
                        disabled: 0
                    )
                ],
                isOn: compareValues(
                    1, 
                    PlistEditor.readValue(filePath: self.modifiedMobileGestalt!.path, keyPath: ["CacheExtra", "e0HV2blYUDBk/MsMEQACNA"])
                ),
                isDisabled: Version(UIDevice.current.systemVersion) < Version("18.0")
            )
        ]
    }
}
