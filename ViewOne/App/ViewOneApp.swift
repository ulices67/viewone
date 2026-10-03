import SwiftUI

@main
struct ViewOneApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var vaultManager = VaultManager.shared
    @StateObject private var screenshotObserver = ScreenshotObserver.shared
    @StateObject private var captureEngine = CaptureEngine.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(vaultManager)
                .environmentObject(screenshotObserver)
                .environmentObject(captureEngine)
                .onAppear {
                    vaultManager.purgeExpiredItems()
                }
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .background:
                        // Automatically lock vault when moving to background
                        vaultManager.lockVault()
                        vaultManager.purgeExpiredItems()
                    case .active:
                        vaultManager.purgeExpiredItems()
                    default:
                        break
                    }
                }
        }
    }
}
