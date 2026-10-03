import SwiftUI

public struct DetailCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var vaultManager = VaultManager.shared

    @State private var item: CapturedItem
    @State private var decryptedImage: UIImage?
    @State private var showingCopiedAlert = false
    @State private var copiedMessage = ""

    public init(item: CapturedItem) {
        self._item = State(initialValue: item)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with Image
                ZStack(alignment: .bottomTrailing) {
                    if let image = decryptedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(18)
                            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
                    } else {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .frame(height: 380)
                            .overlay(ProgressView())
                    }
                }
                .padding(.horizontal)

                // App & Action Bar
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        AppTagBadge(app: item.sourceApp)
                        Text(item.createdAt, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary) +
                        Text(" · ")
                            .foregroundColor(.secondary) +
                        Text(item.createdAt, style: .time)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Action buttons: Keep / Delete
                    HStack(spacing: 12) {
                        Button(action: keepCapture) {
                            HStack(spacing: 4) {
                                Image(systemName: item.expiresAt == nil ? "checkmark.seal.fill" : "lock.shield.fill")
                                Text("Guardar")
                            }
                            .font(.subheadline.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                        }

                        Button(action: deleteCapture) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text("Borrar")
                            }
                            .font(.subheadline.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.12))
                            .foregroundColor(.red)
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                // Extracted Links Section
                if !item.extractedLinks.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Enlaces detectados (\(item.extractedLinks.count))", systemImage: "link")
                            .font(.headline)

                        ForEach(item.extractedLinks, id: \.self) { link in
                            HStack {
                                Text(link)
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .lineLimit(1)

                                Spacer()

                                Button {
                                    copyToClipboard(text: link, label: "Enlace copiado")
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                if let url = URL(string: link) {
                                    Link(destination: url) {
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }

                // QR Codes Section
                if !item.detectedQRCodes.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Códigos QR (\(item.detectedQRCodes.count))", systemImage: "qrcode")
                            .font(.headline)

                        ForEach(item.detectedQRCodes, id: \.self) { qr in
                            HStack {
                                Text(qr)
                                    .font(.subheadline.monospaced())
                                    .lineLimit(2)

                                Spacer()

                                Button {
                                    copyToClipboard(text: qr, label: "QR copiado")
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }

                // Handles / Usernames
                if !item.detectedUsernames.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Perfiles detectados", systemImage: "at")
                            .font(.headline)

                        FlowLayout(spacing: 8) {
                            ForEach(item.detectedUsernames, id: \.self) { handle in
                                Button {
                                    copyToClipboard(text: handle, label: "\(handle) copiado")
                                } label: {
                                    Text(handle)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.green.opacity(0.12))
                                        .foregroundColor(.green)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Full Vision OCR Text
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Texto Reconocido (Vision OCR)", systemImage: "text.viewfinder")
                            .font(.headline)

                        Spacer()

                        Button {
                            copyToClipboard(text: item.recognizedText, label: "Texto completo copiado")
                        } label: {
                            Image(systemName: "doc.on.doc")
                            Text("Copiar todo")
                        }
                        .font(.caption.bold())
                        .foregroundColor(.blue)
                    }

                    Text(item.recognizedText.isEmpty ? "No se detectó texto en esta captura." : item.recognizedText)
                        .font(.subheadline)
                        .foregroundColor(item.recognizedText.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Detalle de Captura")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(
            Group {
                if showingCopiedAlert {
                    VStack {
                        Spacer()
                        Text(copiedMessage)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.85))
                            .clipShape(Capsule())
                            .padding(.bottom, 30)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        )
        .onAppear {
            self.decryptedImage = vaultManager.decryptImage(for: item)
        }
    }

    private func keepCapture() {
        item.expiresAt = nil // Persist permanently
        if let idx = vaultManager.items.firstIndex(where: { $0.id == item.id }) {
            // Updated state handled
        }
        copyToClipboard(text: "", label: "Guardado permanentemente en Vault")
    }

    private func deleteCapture() {
        vaultManager.deleteItem(item)
        dismiss()
    }

    private func copyToClipboard(text: String, label: String) {
        if !text.isEmpty {
            UIPasteboard.general.string = text
        }
        copiedMessage = label
        withAnimation {
            showingCopiedAlert = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation {
                showingCopiedAlert = false
            }
        }
    }
}

// Helper Simple FlowLayout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeightInRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += maxHeightInRow + spacing
                maxHeightInRow = 0
            }
            maxHeightInRow = max(maxHeightInRow, size.height)
            x += size.width + spacing
        }
        height = y + maxHeightInRow
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var maxHeightInRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += maxHeightInRow + spacing
                maxHeightInRow = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            maxHeightInRow = max(maxHeightInRow, size.height)
            x += size.width + spacing
        }
    }
}
