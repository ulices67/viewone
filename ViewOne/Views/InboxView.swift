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
        return observer.items.isEmpty ? vaultManager.items : observer.items
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
                // Processing or Status Bar
                if observer.isProcessing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(observer.statusMessage)
                            .font(.caption.bold())
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                }

                // Category Pills (Instagram, WhatsApp, etc.)
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
                } else if filteredItems.isEmpty && !observer.isProcessing {
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
                    .refreshable {
                        await observer.syncScreenshots()
                    }
                }
            }
            .navigationTitle("Screenshot Inbox")
            .searchable(text: $searchText, prompt: "Buscar en texto OCR, enlaces o perfiles...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await observer.syncScreenshots()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.body.weight(.semibold))
                    }
                    .disabled(observer.isProcessing)
                }
            }
            .task {
                if observer.authorizationStatus == .notDetermined {
                    _ = await observer.requestPermissionAndSync()
                } else {
                    await observer.syncScreenshots()
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

            Text("Para organizar automáticamente las capturas que tomas en WhatsApp, Instagram, Safari y otras apps, ViewOne necesita permiso de lectura en Fotos.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)

            Button {
                Task {
                    _ = await observer.requestPermissionAndSync()
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

            Text("No hay capturas detectadas")
                .font(.headline)

            Text("Toma una captura de pantalla en cualquier app (Botón Lateral + Volumen Arriba) y pulsa el botón de actualizar arriba.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task {
                    await observer.syncScreenshots()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Buscar capturas ahora")
                }
                .font(.subheadline.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.12))
                .foregroundColor(.blue)
                .clipShape(Capsule())
            }

            Spacer()
        }
    }
}
