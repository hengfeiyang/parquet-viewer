import SwiftUI

@main
struct ParquetViewerDemoApp: App {
    init() {
        // Set up the library path for the Rust library
        setupLibraryPath()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
    }
    
    private func setupLibraryPath() {
        // Get the path to the Rust library
        if let bundlePath = Bundle.main.resourcePath {
            let libraryPath = bundlePath + "/Frameworks"
            setenv("DYLD_LIBRARY_PATH", libraryPath, 1)
        }
    }
}
