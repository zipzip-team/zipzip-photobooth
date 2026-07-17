import SwiftUI

@main
struct PhotoPrintBoothApp: App {
    @StateObject private var camera = CameraModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(camera)
                .frame(minWidth: 1120, minHeight: 760)
                .task {
                    await camera.requestAndStart()
                }
        }
        .windowStyle(.titleBar)
    }
}
