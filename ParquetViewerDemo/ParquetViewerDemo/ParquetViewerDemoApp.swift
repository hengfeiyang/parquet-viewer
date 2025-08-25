import SwiftUI

@main
struct ParquetViewerDemoApp: App {
    init() {
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
