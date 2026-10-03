import SwiftUI
import PhotosUI

public struct QuickCaptureView: View {
    @ObservedObject private var observer = ScreenshotObserver.shared
    @ObservedObject private var vaultManager = VaultManager.shared
    @ObservedObject private var engine = CaptureEngine.shared

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var lastAnalyzedItem: CapturedItem? = nil
    @State private var isAnalyzing = false
    @State private var showHowToGuide = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header card
                    headerStatusCard

                    // Primary Action: Real PhotoKit Sync
                    syncCard

                    // Secondary Action: Direct PhotosPicker (100% real y funcional en iOS)
                    manualImportCard

                    // Guía de cómo funciona el sistema en iPhone
                    howItWorksCard

                    // Vault Settings
                    settingsCard
                }
                .padding()
            }
            .navigationTitle("Asistente de Captura")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $lastAnalyzedItem) { item in
                NavigationStack {
                    DetailCaptureView(item: item)
                }
            }
            .sheet(isPresented: $showHowToGuide) {
                backTapGuideSheet
            }
            .onChange(of: selectedPhotoItem) { newItem in
                if let newItem = newItem {
                    handlePickedPhoto(newItem)
                }
            }
        }
    }

    // MARK: - Header Status Card
    private var headerStatusCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 32))
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 3) {
                Text("Motor Vision OCR Activo")
                    .font(.headline)
                Text(observer.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Sync Now Card
    private var syncCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Sincronización Automática", systemImage: "bolt.fill")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Cada vez que hagas una captura en WhatsApp, Instagram, TikTok o Safari (**Botón Lateral + Volumen Arriba**), pulsa aquí o abre la app para clasificarla al instante:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button {
                Task {
                    await observer.syncScreenshots()
                }
            } label: {
                HStack {
                    if observer.isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text(observer.isProcessing ? "Procesando capturas..." : "Escanear Capturas de la Fototeca")
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(observer.isProcessing)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(18)
    }

    // MARK: - Manual Import Card (PhotosPicker)
    private var manualImportCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Importar y Analizar Manualmente", systemImage: "photo.badge.plus")
                .font(.headline)

            Text("Selecciona cualquier captura o imagen de tu carrete para probar el análisis OCR inmediato y guardarla en la bóveda:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .screenshots,
                photoLibrary: .shared()
            ) {
                HStack {
                    if isAnalyzing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "square.and.arrow.down.on.square.fill")
                    }
                    Text(isAnalyzing ? "Analizando imagen..." : "Elegir Captura del Carrete")
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.indigo)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(isAnalyzing)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(18)
    }

    // MARK: - How It Works
    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("La Realidad de iOS", systemImage: "exclamationmark.shield")
                    .font(.headline)
                    .foregroundColor(.orange)
                Spacer()
            }

            Text("Apple **no permite** que ninguna aplicación tome capturas silenciosas de otras apps en segundo plano con temporizadores ni botones flotantes (por privacidad y seguridad bancaria).")
                .font(.footnote)
                .foregroundColor(.secondary)

            Button {
                showHowToGuide = true
            } label: {
                HStack {
                    Image(systemName: "hand.tap.fill")
                    Text("Configurar 'Tocar Atrás' para capturar con 2 toques")
                }
                .font(.caption.bold())
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.08))
        .cornerRadius(18)
    }

    // MARK: - Settings Card
    private var settingsCard: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $engine.autoDelete24h) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Caducidad en 24 horas")
                        .font(.subheadline.weight(.semibold))
                    Text("Elimina automáticamente las capturas temporales del Vault")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Handle Picked Photo
    private func handlePickedPhoto(_ item: PhotosPickerItem) {
        isAnalyzing = true
        Task {
            defer {
                isAnalyzing = false
                selectedPhotoItem = nil
            }

            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                return
            }

            do {
                let analysis = try await VisionAnalyzer.shared.analyze(image: uiImage)
                var captured = CapturedItem(
                    id: UUID(),
                    createdAt: Date(),
                    sourceApp: analysis.estimatedApp,
                    recognizedText: analysis.fullText,
                    extractedLinks: analysis.detectedLinks,
                    detectedQRCodes: analysis.qrCodes,
                    detectedUsernames: analysis.usernames,
                    detectedPhoneNumbers: analysis.phoneNumbers,
                    isVaultProtected: true,
                    expiresAt: engine.autoDelete24h ? Calendar.current.date(byAdding: .hour, value: 24, to: Date()) : nil,
                    relativeImagePath: "",
                    duplicateHash: analysis.contentHash
                )

                try VaultManager.shared.encryptAndSave(image: uiImage, metadata: &captured)
                await observer.syncScreenshots()
                self.lastAnalyzedItem = captured
            } catch {
                print("Error analizando imagen: \(error)")
            }
        }
    }

    // MARK: - Guide Sheet
    private var backTapGuideSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Capturar sin tocar botones")
                    .font(.title2.bold())

                Text("En iPhone puedes hacer que 2 toques con el dedo en la parte trasera tomen una captura en cualquier app:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 14) {
                    guideStep(num: "1", title: "Abre Ajustes de iOS", desc: "Ve a la app Ajustes de tu iPhone.")
                    guideStep(num: "2", title: "Accesibilidad", desc: "Selecciona Accesibilidad > Tocar.")
                    guideStep(num: "3", title: "Tocar atrás", desc: "Baja al final de la pantalla y pulsa 'Tocar atrás'.")
                    guideStep(num: "4", title: "Pulsar dos veces", desc: "Selecciona 'Captura de pantalla'.")
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)

                Text("A partir de ese momento, cuando estés en WhatsApp o Instagram, dale 2 toques a la parte trasera del iPhone. La captura se creará y ViewOne la clasificará al instante.")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    showHowToGuide = false
                } label: {
                    Text("Entendido")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func guideStep(num: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(num)
                .font(.headline)
                .frame(width: 28, height: 28)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
