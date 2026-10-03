import Foundation
import CryptoKit
import LocalAuthentication
import UIKit
import Combine

@MainActor
public final class VaultManager: ObservableObject {
    public static let shared = VaultManager()

    @Published public private(set) var items: [CapturedItem] = []
    @Published public private(set) var isUnlocked: Bool = false
    @Published public var authenticationError: String?

    private let fileManager = FileManager.default
    private let keychainService = "com.viewone.capturevault"
    private let keyAccount = "vaultMasterKey"
    private let metadataFileName = "vault_metadata.json"

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var vaultDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("EncryptedVault", isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    private init() {
        loadMetadata()
        purgeExpiredItems()
    }

    // MARK: - Biometric Authentication (Face ID / Touch ID)
    public func authenticateBiometrics() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancelar"
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Desbloquea Capture Vault para ver tus capturas cifradas."
            do {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                self.isUnlocked = success
                return success
            } catch {
                self.authenticationError = error.localizedDescription
                // Fallback to passcode
                return await authenticatePasscode(context: context)
            }
        } else {
            return await authenticatePasscode(context: context)
        }
    }

    private func authenticatePasscode(context: LAContext) async -> Bool {
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Introduce tu código para desbloquear Capture Vault.")
            self.isUnlocked = success
            return success
        } catch {
            self.authenticationError = error.localizedDescription
            self.isUnlocked = false
            return false
        }
    }

    public func lockVault() {
        self.isUnlocked = false
    }

    // MARK: - Encryption & Decryption (CryptoKit AES-GCM)
    private func getOrCreateSymmetricKey() -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keyAccount,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess, let data = item as? Data {
            return SymmetricKey(data: data)
        }

        // Generate new 256-bit AES key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keyAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(addQuery as CFDictionary, nil)
        return newKey
    }

    public func encryptAndSave(image: UIImage, metadata: inout CapturedItem) throws {
        guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
            throw NSError(domain: "VaultManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Error al convertir imagen a JPEG"])
        }

        let key = getOrCreateSymmetricKey()
        let sealedBox = try AES.GCM.seal(jpegData, using: key)
        guard let encryptedData = sealedBox.combined else {
            throw NSError(domain: "VaultManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Fallo en el cifrado AES-GCM"])
        }

        let fileName = "\(metadata.id.uuidString).enc"
        let fileURL = vaultDirectory.appendingPathComponent(fileName)
        try encryptedData.write(to: fileURL, options: .atomic)

        metadata.relativeImagePath = fileName
        items.insert(metadata, at: 0)
        saveMetadata()
    }

    public func decryptImage(for item: CapturedItem) -> UIImage? {
        let fileURL = vaultDirectory.appendingPathComponent(item.relativeImagePath)
        guard let encryptedData = try? Data(contentsOf: fileURL) else { return nil }

        let key = getOrCreateSymmetricKey()
        guard let sealedBox = try? AES.GCM.SealedBox(combined: encryptedData),
              let decryptedData = try? AES.GCM.open(sealedBox, using: key) else {
            return nil
        }

        return UIImage(data: decryptedData)
    }

    public func deleteItem(_ item: CapturedItem) {
        let fileURL = vaultDirectory.appendingPathComponent(item.relativeImagePath)
        try? fileManager.removeItem(at: fileURL)
        items.removeAll(where: { $0.id == item.id })
        saveMetadata()
    }

    // MARK: - Expiration (24h Auto-deletion)
    public func purgeExpiredItems() {
        let now = Date()
        let expired = items.filter { item in
            if let exp = item.expiresAt {
                return now > exp
            }
            return false
        }

        for item in expired {
            deleteItem(item)
        }
    }

    // MARK: - Metadata Persistence
    private func saveMetadata() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(items) {
            let metadataURL = vaultDirectory.appendingPathComponent(metadataFileName)
            try? data.write(to: metadataURL, options: .atomic)
        }
    }

    private func loadMetadata() {
        let metadataURL = vaultDirectory.appendingPathComponent(metadataFileName)
        guard let data = try? Data(contentsOf: metadataURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let loaded = try? decoder.decode([CapturedItem].self, from: data) {
            self.items = loaded
        }
    }
}
