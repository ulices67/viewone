import SwiftUI

public struct VaultView: View {
    @ObservedObject private var vaultManager = VaultManager.shared
    @State private var isAuthenticating = false
    @State private var filterExpiringOnly = false

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    public init() {}

    private var itemsToDisplay: [CapturedItem] {
        if filterExpiringOnly {
            return vaultManager.items.filter { $0.expiresAt != nil }
        }
        return vaultManager.items
    }

    public var body: some View {
        NavigationStack {
            Group {
                if !vaultManager.isUnlocked {
                    lockedStateView
                } else {
                    unlockedVaultContent
                }
            }
            .navigationTitle("Capture Vault")
            .toolbar {
                if vaultManager.isUnlocked {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            withAnimation {
                                vaultManager.lockVault()
                            }
                        } label: {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Locked View (Biometrics prompt)
    private var lockedStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 120, height: 120)

                Image(systemName: "faceid")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
            }

            VStack(spacing: 8) {
                Text("Bóveda Protegida")
                    .font(.title2.bold())

                Text("Las capturas aquí almacenadas están cifradas en reposo con AES-GCM (CryptoKit) y protegidas con Face ID.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }

            if let error = vaultManager.authenticationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            Button {
                authenticate()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "faceid")
                    Text("Desbloquear con Face ID")
                }
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(14)
                .padding(.horizontal, 40)
            }
            .disabled(isAuthenticating)

            Spacer()
        }
        .onAppear {
            authenticate()
        }
    }

    private func authenticate() {
        guard !vaultManager.isUnlocked else { return }
        isAuthenticating = true
        Task {
            _ = await vaultManager.authenticateBiometrics()
            isAuthenticating = false
        }
    }

    // MARK: - Unlocked Content
    private var unlockedVaultContent: some View {
        VStack(spacing: 0) {
            // Vault Info Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("Cifrado AES-256 Activo")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }

                Spacer()

                Button {
                    withAnimation {
                        filterExpiringOnly.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: filterExpiringOnly ? "clock.fill" : "clock")
                        Text(filterExpiringOnly ? "Solo temporales (24h)" : "Todos")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(filterExpiringOnly ? Color.orange.opacity(0.15) : Color(UIColor.secondarySystemBackground))
                    .foregroundColor(filterExpiringOnly ? .orange : .primary)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            if itemsToDisplay.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "lock.doc")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Bóveda vacía")
                        .font(.headline)
                    Text("Tus capturas guardadas en Quick Capture o marcadas para conservar aparecerán aquí.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(itemsToDisplay) { item in
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
    }
}
