import Foundation
import ReplayKit
import CoreMedia
import CoreVideo
import UIKit
import Combine

@MainActor
public final class CaptureEngine: ObservableObject {
    public static let shared = CaptureEngine()

    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var isScreenCapturedBySystem: Bool = false
    @Published public private(set) var lastCapturedImage: UIImage?
    @Published public private(set) var lastCaptureTime: Date?
    @Published public var autoDelete24h: Bool = true
    @Published public var errorMessage: String?

    private let recorder = RPScreenRecorder.shared()
    private var latestSampleBuffer: CMSampleBuffer?
    private let bufferQueue = DispatchQueue(label: "com.viewone.capturebuffer", qos: .userInteractive)

    private init() {
        checkSystemCaptureStatus()
        NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkSystemCaptureStatus()
        }
    }

    private func checkSystemCaptureStatus() {
        self.isScreenCapturedBySystem = UIScreen.main.isCaptured
    }

    // MARK: - Iniciar Sesión de Captura Autorizada
    public func startCaptureSession() {
        guard recorder.isAvailable else {
            self.errorMessage = "La grabación de pantalla de ReplayKit no está disponible en este dispositivo."
            return
        }

        guard !isRecording else { return }

        // RPScreenRecorder pide consentimiento explícito del usuario a través de la UI del sistema
        recorder.startCapture { [weak self] (sampleBuffer, bufferType, error) in
            guard let self = self else { return }

            if let error = error {
                Task { @MainActor in
                    self.errorMessage = "Error en sesión de captura: \(error.localizedDescription)"
                    self.isRecording = false
                }
                return
            }

            // Solo retenemos los buffers de video de la pantalla
            if bufferType == .video {
                self.bufferQueue.async {
                    // Mantenemos únicamente el frame más reciente en memoria volátil
                    self.latestSampleBuffer = sampleBuffer
                }
            }
        } completionHandler: { [weak self] error in
            Task { @MainActor in
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    self?.isRecording = false
                } else {
                    self?.isRecording = true
                    self?.errorMessage = nil
                }
            }
        }
    }

    // MARK: - Detener Sesión de Captura
    public func stopCaptureSession() {
        guard isRecording else { return }

        recorder.stopCapture { [weak self] error in
            Task { @MainActor in
                self?.isRecording = false
                self?.bufferQueue.async {
                    self?.latestSampleBuffer = nil
                }
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Disparador Manual: Guardar el Frame Actual
    public func captureCurrentFrame() async -> CapturedItem? {
        var bufferToProcess: CMSampleBuffer?
        bufferQueue.sync {
            bufferToProcess = self.latestSampleBuffer
        }

        guard let sampleBuffer = bufferToProcess,
              let image = convertSampleBufferToUIImage(sampleBuffer: sampleBuffer) else {
            // Fallback si ReplayKit no tiene un buffer o el usuario captura en-app
            return await captureFallbackScreenshot()
        }

        return await processAndStoreCapture(image: image)
    }

    private func captureFallbackScreenshot() async -> CapturedItem? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }

        return await processAndStoreCapture(image: image)
    }

    private func processAndStoreCapture(image: UIImage) async -> CapturedItem? {
        self.lastCapturedImage = image
        self.lastCaptureTime = Date()

        do {
            let analysis = try await VisionAnalyzer.shared.analyze(image: image)
            let expiryDate = autoDelete24h ? Calendar.current.date(byAdding: .hour, value: 24, to: Date()) : nil

            var item = CapturedItem(
                id: UUID(),
                createdAt: Date(),
                sourceApp: analysis.estimatedApp,
                recognizedText: analysis.fullText,
                extractedLinks: analysis.detectedLinks,
                detectedQRCodes: analysis.qrCodes,
                detectedUsernames: analysis.usernames,
                detectedPhoneNumbers: analysis.phoneNumbers,
                isVaultProtected: true,
                expiresAt: expiryDate,
                relativeImagePath: "",
                duplicateHash: analysis.contentHash
            )

            try VaultManager.shared.encryptAndSave(image: image, metadata: &item)
            return item
        } catch {
            self.errorMessage = "Error al procesar la captura: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - CMSampleBuffer a UIImage
    private func convertSampleBufferToUIImage(sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
