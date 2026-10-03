import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab: Int = 0

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            InboxView()
                .tabItem {
                    Label("Inbox", systemImage: "tray.full.fill")
                }
                .tag(0)

            QuickCaptureView()
                .tabItem {
                    Label("Captura Rápida", systemImage: "camera.viewfinder")
                }
                .tag(1)

            VaultView()
                .tabItem {
                    Label("Vault Cifrado", systemImage: "lock.shield.fill")
                }
                .tag(2)
        }
        .tint(.blue)
    }
}
