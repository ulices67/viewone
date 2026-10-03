import Foundation
import UIKit
import Vision

public final class VisionAnalyzer {
    public static let shared = VisionAnalyzer()

    private init() {}

    public struct AnalysisResult {
        public let fullText: String
        public let detectedLinks: [String]
        public let qrCodes: [String]
        public let usernames: [String]
        public let phoneNumbers: [String]
        public let estimatedApp: SourceApp
        public let contentHash: String
    }

    public func analyze(image: UIImage) async throws -> AnalysisResult {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "VisionAnalyzer", code: -1, userInfo: [NSLocalizedDescriptionKey: "CGImage no disponible"])
        }

        return try await withCheckedThrowingContinuation { continuation in
            var recognizedLines: [String] = []
            var detectedQRs: [String] = []

            // 1. OCR Request
            let textRequest = VNRecognizeTextRequest { request, error in
                if let observations = request.results as? [VNRecognizedTextObservation] {
                    for observation in observations {
                        if let topCandidate = observation.topCandidates(1).first {
                            recognizedLines.append(topCandidate.string)
                        }
                    }
                }
            }
            textRequest.recognitionLevel = .accurate
            textRequest.recognitionLanguages = ["es-ES", "en-US"]
            textRequest.usesLanguageCorrection = true

            // 2. Barcode / QR Request
            let barcodeRequest = VNDetectBarcodesRequest { request, error in
                if let observations = request.results as? [VNBarcodeObservation] {
                    for observation in observations {
                        if let payload = observation.payloadStringValue {
                            detectedQRs.append(payload)
                        }
                    }
                }
            }
            barcodeRequest.symbologies = [.qr, .ean13, .ean8, .code128]

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            do {
                try handler.perform([textRequest, barcodeRequest])

                let fullText = recognizedLines.joined(separator: "\n")
                let links = self.extractLinks(from: fullText)
                let phones = self.extractPhoneNumbers(from: fullText)
                let handles = self.extractUsernames(from: fullText)
                let app = self.estimateSourceApp(from: fullText)
                let hash = self.computeSimpleHash(for: fullText)

                let result = AnalysisResult(
                    fullText: fullText,
                    detectedLinks: links,
                    qrCodes: detectedQRs,
                    usernames: handles,
                    phoneNumbers: phones,
                    estimatedApp: app,
                    contentHash: hash
                )
                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Data Detectors (Links & Phone numbers)
    private func extractLinks(from text: String) -> [String] {
        var links: [String] = []
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return links
        }
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        for match in matches {
            if let url = match.url?.absoluteString {
                links.append(url)
            }
        }
        return Array(Set(links))
    }

    private func extractPhoneNumbers(from text: String) -> [String] {
        var phones: [String] = []
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue) else {
            return phones
        }
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        for match in matches {
            if let phone = match.phoneNumber {
                phones.append(phone)
            }
        }
        return Array(Set(phones))
    }

    // MARK: - Regex for Handles / Usernames (@name)
    private func extractUsernames(from text: String) -> [String] {
        let pattern = #"(?<=^|(?<=[^a-zA-Z0-9_.]))@([A-Za-z0-9_.]{2,30})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.utf16.count))
        var results: [String] = []
        for match in matches {
            if let range = Range(match.range, in: text) {
                results.append(String(text[range]))
            }
        }
        return Array(Set(results))
    }

    // MARK: - Source App Heuristics
    public func estimateSourceApp(from text: String) -> SourceApp {
        let lower = text.lowercased()

        // WhatsApp Indicators
        if lower.contains("escribe un mensaje") ||
           lower.contains("cifrado de extremo a extremo") ||
           lower.contains("en línea") ||
           lower.contains("info. del contacto") ||
           lower.contains("hoy a las") && (lower.contains("llamada") || lower.contains("visto")) {
            return .whatsApp
        }

        // Instagram Indicators
        if lower.contains("siguiendo") && lower.contains("mensajes") ||
           lower.contains("ver traducción") ||
           lower.contains("reels") ||
           lower.contains("historias") ||
           lower.contains("enviar mensaje") && lower.contains("perfil") {
            return .instagram
        }

        // TikTok Indicators
        if lower.contains("para ti") && lower.contains("siguiendo") ||
           lower.contains("añadir comentario") ||
           lower.contains("sonido original") ||
           lower.contains("tiktok") {
            return .tikTok
        }

        // X (Twitter) Indicators
        if lower.contains("repost") ||
           lower.contains("postea tu respuesta") ||
           lower.contains("tendencias para ti") ||
           lower.contains("buscar en x") ||
           lower.contains("para ti") && lower.contains("posts") {
            return .xTwitter
        }

        // Telegram Indicators
        if lower.contains("mensajes guardados") ||
           lower.contains("reenviado de") ||
           lower.contains("suscriptores") ||
           lower.contains("unirse al canal") {
            return .telegram
        }

        // Safari Indicators
        if lower.contains("buscar o escribir sitio") ||
           lower.contains("página principal") ||
           lower.contains("compartir pestaña") ||
           lower.contains("lector disponible") ||
           lower.contains(".com/") || lower.contains(".org/") || lower.contains(".es/") {
            return .safari
        }

        // YouTube Indicators
        if lower.contains("suscribirse") ||
           lower.contains("shorts") ||
           lower.contains("reproducir todo") ||
           lower.contains("me gusta") && lower.contains("no me gusta") {
            return .youtube
        }

        return .unknown
    }

    private func computeSimpleHash(for text: String) -> String {
        let cleaned = text.filter { $0.isLetter || $0.isNumber }
        return String(cleaned.prefix(120).hashValue)
    }
}
