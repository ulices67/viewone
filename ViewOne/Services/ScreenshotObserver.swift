import Foundation
import Photos
import UIKit
import Combine

@MainActor
public final class ScreenshotObserver: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    public static let shared = ScreenshotObserver()

    @Published public private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published public private(set) var items: [CapturedItem] = []
    @Published public private(set) var isProcessing: Bool = false
    @Published public private(set) var statusMessage: String = "Iniciando..."
    @Published public var lastCapturedDate: Date?

    private var imageCache = NSCache<NSString, UIImage>()
    private var isObserving = false

    override private init() {
        super.init()
        self.authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if self.authorizationStatus == .authorized || self.authorizationStatus == .limited {
            startObserving()
        }
    }

    public func requestPermissionAndSync() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        self.authorizationStatus = status

        if status == .authorized || status == .limited {
            startObserving()
            await syncScreenshots()
            return true
        } else {
            self.statusMessage = "Permiso denegado por el usuario"
            return false
        }
    }

    public func startObserving() {
        guard !isObserving else { return }
        PHPhotoLibrary.shared().register(self)
        self.isObserving = true
    }

    public func stopObserving() {
        guard isObserving else { return }
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        self.isObserving = false
    }

    // MARK: - Sincronizar Capturas de la Fototeca
    public func syncScreenshots() async {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            return
        }

        self.isProcessing = true
        self.statusMessage = "Buscando capturas de pantalla..."
        defer { self.isProcessing = false }

        // Fetch recent screenshots
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        fetchOptions.fetchLimit = 30

        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        self.statusMessage = "Encontradas \(assets.count) capturas. Procesando..."

        var existingIdentifiers = Set(VaultManager.shared.items.compactMap { $0.localIdentifier })
        var newItems: [CapturedItem] = []

        // Procesa hasta 30 capturas recientes de forma concurrente pero segura
        for i in 0..<assets.count {
            let asset = assets.object(at: i)
            if existingIdentifiers.contains(asset.localIdentifier) {
                continue // Ya procesada previamente
            }

            if let image = await fetchHighQualityImage(for: asset) {
                // Guarda en memoria caché inmediata
                self.imageCache.setObject(image, forKey: asset.localIdentifier as NSString)

                // Analizar con Vision OCR
                do {
                    let analysis = try await VisionAnalyzer.shared.analyze(image: image)
                    var item = CapturedItem(
                        id: UUID(),
                        createdAt: asset.creationDate ?? Date(),
                        sourceApp: analysis.estimatedApp,
                        recognizedText: analysis.fullText,
                        extractedLinks: analysis.detectedLinks,
                        detectedQRCodes: analysis.qrCodes,
                        detectedUsernames: analysis.usernames,
                        detectedPhoneNumbers: analysis.phoneNumbers,
                        isVaultProtected: true,
                        expiresAt: nil,
                        relativeImagePath: "",
                        duplicateHash: analysis.contentHash,
                        localIdentifier: asset.localIdentifier
                    )

                    // Cifrar y guardar en disco en VaultManager
                    try VaultManager.shared.encryptAndSave(image: image, metadata: &item)
                    existingIdentifiers.insert(asset.localIdentifier)
                    newItems.append(item)
                } catch {
                    print("Error analizando captura \(asset.localIdentifier): \(error.localizedDescription)")
                }
            }
        }

        // Refrescar lista de items
        self.items = VaultManager.shared.items
        self.statusMessage = "Listo (\(self.items.count) capturas organizadas)"
    }

    // MARK: - PHPhotoLibraryChangeObserver (En tiempo real)
    public nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            // Cuando la fototeca cambia (ej. el usuario hace una captura de pantalla en cualquier app)
            // volvemos a sincronizar inmediatamente
            await self.syncScreenshots()
        }
    }

    // MARK: - Extracción limpia y asíncrona de imagen desde PHAsset
    private func fetchHighQualityImage(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            var hasResumed = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 1170, height: 2532),
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded && !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: image)
                }
            }

            // Fallback por si tarda o falla
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Recuperar Imagen desde Caché o Vault
    public func getImage(for item: CapturedItem) -> UIImage? {
        if let localId = item.localIdentifier, let cached = imageCache.object(forKey: localId as NSString) {
            return cached
        }
        if let decrypted = VaultManager.shared.decryptImage(for: item) {
            if let localId = item.localIdentifier {
                imageCache.setObject(decrypted, forKey: localId as NSString)
            }
            return decrypted
        }
        return nil
    }
}
