import Foundation
import Photos
import UIKit
import Combine

@MainActor
public final class ScreenshotObserver: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    public static let shared = ScreenshotObserver()

    @Published public private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published public private(set) var recentScreenshots: [CapturedItem] = []
    @Published public private(set) var isProcessing: Bool = false
    @Published public var lastCapturedDate: Date?

    private var fetchResult: PHFetchResult<PHAsset>?
    private let imageManager = PHCachingImageManager()

    override private init() {
        super.init()
        self.authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    public func requestPermission() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        self.authorizationStatus = status
        if status == .authorized || status == .limited {
            startObserving()
            loadInitialScreenshots()
            return true
        }
        return false
    }

    public func startObserving() {
        PHPhotoLibrary.shared().register(self)
    }

    public func stopObserving() {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    public func loadInitialScreenshots() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        options.fetchLimit = 50

        let result = PHAsset.fetchAssets(with: .image, options: options)
        self.fetchResult = result

        // Process latest screenshots if needed
        Task {
            await self.processAssets(result)
        }
    }

    // MARK: - PHPhotoLibraryChangeObserver
    public nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            guard let currentFetch = self.fetchResult,
                  let details = changeInstance.changeDetails(for: currentFetch) else {
                return
            }

            self.fetchResult = details.fetchResultAfterChanges

            // Detect newly inserted screenshots
            let inserted = details.insertedObjects
            if !inserted.isEmpty {
                for asset in inserted {
                    await self.processSingleAsset(asset)
                }
            }
        }
    }

    private func processAssets(_ assets: PHFetchResult<PHAsset>) async {
        self.isProcessing = true
        defer { self.isProcessing = false }

        var items: [CapturedItem] = []
        let group = DispatchGroup()

        assets.enumerateObjects { asset, index, stop in
            if index >= 30 {
                stop.pointee = true
                return
            }
            group.enter()
            self.fetchImage(for: asset) { image in
                defer { group.leave() }
                guard let image = image else { return }

                // Quick placeholder
                let item = CapturedItem(
                    id: UUID(),
                    createdAt: asset.creationDate ?? Date(),
                    sourceApp: .unknown,
                    recognizedText: "",
                    extractedLinks: [],
                    detectedQRCodes: [],
                    detectedUsernames: [],
                    detectedPhoneNumbers: [],
                    isVaultProtected: false,
                    expiresAt: nil,
                    relativeImagePath: ""
                )
                items.append(item)
            }
        }

        group.wait()
        self.recentScreenshots = items
    }

    private func processSingleAsset(_ asset: PHAsset) async {
        self.isProcessing = true
        defer { self.isProcessing = false }

        self.lastCapturedDate = asset.creationDate ?? Date()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.fetchImage(for: asset) { image in
                guard let image = image else {
                    continuation.resume()
                    return
                }

                Task {
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
                            expiresAt: Calendar.current.date(byAdding: .hour, value: 24, to: Date()),
                            relativeImagePath: "",
                            duplicateHash: analysis.contentHash
                        )

                        // Save securely in Vault
                        try VaultManager.shared.encryptAndSave(image: image, metadata: &item)
                        self.recentScreenshots.insert(item, at: 0)
                    } catch {
                        print("Error procesando screenshot: \(error.localizedDescription)")
                    }
                    continuation.resume()
                }
            }
        }
    }

    private func fetchImage(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 1080, height: 1920),
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            completion(image)
        }
    }
}
