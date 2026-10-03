import SwiftUI
import Photos

public struct InboxView: View {
    @ObservedObject private var observer = ScreenshotObserver.shared
    @ObservedObject private var vaultManager = VaultManager.shared

    @State private var selectedAppFilter: SourceApp? = nil
    @State private var searchText = ""

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    public init() {}

    private var allItems: [CapturedItem] {
        // Combina los items detectados por el observer y los del vault
        var list = vaultManager.items
        for item in observer.recentScreenshots {
            if !list.contains(where: { $0.id == item.id }) {
                list.append(item)
            }
        }
        return list
    }

    private var filteredItems: [CapturedItem] {
        var result = allItems

        if let filter = selectedAppFilter {
            result = result.filter { $0.sourceApp == filter }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.recognizedText.localizedCaseInsensitiveContains(searchText) ||
                $0.sourceApp.rawValue.localizedCaseInsensitiveContains(searchText) ||
                $0.detectedUsernames.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }

        return result
    }

    private func countForApp(_ app: SourceApp) -> Int {
        allItems.filter { $0.sourceApp == app }.count
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Pills (Instagram 23, WhatsApp 17, etc.)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            withAnimation { selectedAppFilter = nil }
                        } label: {
                            HStack(spacing: 6) {
                                Text("Todos")
                                    .fontWeight(.semibold)
                                Text("\(allItems.count)")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(selectedAppFilter == nil ? Color.white.opacity(0.2) : Color.gray.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedAppFilter == nil ? Color.blue : Color(UIColor.secondarySystemBackground))
                            .foregroundColor(selectedAppFilter == nil ? .white : .primary)
                            .clipShape(Capsule())
                        }

                        ForEach(SourceApp.allCases) { app in
                            let count = countForApp(app)
                            if count > 0 || app == .instagram || app == .whatsApp || app == .tikTok || app == .safari || app == .xTwitter {
                                Button {
                                    withAnimation {
                                        selectedAppFilter = (selectedAppFilter == app) ? nil : app
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: app.iconName)
                                            .font(.caption)
                                        Text(app.rawValue)
                                            .fontWeight(.semibold)
                                        Text("\(count)")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(selectedAppFilter == app ? Color.white.opacity(0.2) : app.brandColor.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedAppFilter == app ? app.brandColor : Color(UIColor.secondarySystemBackground))
                                    .foregroundColor(selectedAppFilter == app ? .white : .primary)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .background(Color(UIColor.systemBackground))

                // Content View
                if observer.authorizationStatus != .authorized && observer.authorizationStatus != .limited {
                    permissionBanner
                } else if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(filteredItems) { item in
                                NavigationLink(destination: DetailCaptureView(item: item)) {
                                    CaptureCardView(item: item)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Screenshot Inbox")
            .searchable(text: $searchText, prompt: "Buscar en texto OCR, enlaces o perfiles...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if observer.isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
            }
        }
    }

    private var permissionBanner: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.stack")
                .font(.system(size: 56))
                .foregroundColor(.blue)

            Text("Acceso a Capturas")
                .font(.title2.bold())

            Text("ViewOne utiliza PhotoKit para detectar cuando tomas un screenshot (Botón lateral + Volumen arriba) y organizarlo al instante con Vision OCR.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)

            Button {
                Task {
                    _ = await observer.requestPermission()
                }
            } label: {
                Text("Permitir Acceso a Fototeca")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No hay capturas")
                .font(.headline)

            Text("Toma una captura de pantalla en cualquier app para que aparezca clasificada automáticamente aquí.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}
