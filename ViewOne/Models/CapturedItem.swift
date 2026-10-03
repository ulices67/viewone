import Foundation
import SwiftUI

public struct CapturedItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let createdAt: Date
    public var sourceApp: SourceApp
    public var recognizedText: String
    public var extractedLinks: [String]
    public var detectedQRCodes: [String]
    public var detectedUsernames: [String]
    public var detectedPhoneNumbers: [String]
    public var isVaultProtected: Bool
    public var expiresAt: Date?
    public var relativeImagePath: String
    public var duplicateHash: String?
    public var localIdentifier: String? // Identificador nativo en PhotoKit (PHAsset)

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        sourceApp: SourceApp = .unknown,
        recognizedText: String = "",
        extractedLinks: [String] = [],
        detectedQRCodes: [String] = [],
        detectedUsernames: [String] = [],
        detectedPhoneNumbers: [String] = [],
        isVaultProtected: Bool = false,
        expiresAt: Date? = nil,
        relativeImagePath: String = "",
        duplicateHash: String? = nil,
        localIdentifier: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceApp = sourceApp
        self.recognizedText = recognizedText
        self.extractedLinks = extractedLinks
        self.detectedQRCodes = detectedQRCodes
        self.detectedUsernames = detectedUsernames
        self.detectedPhoneNumbers = detectedPhoneNumbers
        self.isVaultProtected = isVaultProtected
        self.expiresAt = expiresAt
        self.relativeImagePath = relativeImagePath
        self.duplicateHash = duplicateHash
        self.localIdentifier = localIdentifier
    }

    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
}
