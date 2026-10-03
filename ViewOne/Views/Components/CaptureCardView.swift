import SwiftUI

public struct CaptureCardView: View {
    public let item: CapturedItem
    @State private var image: UIImage?

    public init(item: CapturedItem) {
        self.item = item
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(UIColor.secondarySystemBackground))
                            .frame(height: 180)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .cornerRadius(14)

                // App Badge Overlay
                AppTagBadge(app: item.sourceApp)
                    .padding(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    if item.expiresAt != nil {
                        HStack(spacing: 3) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("24h")
                        }
                        .font(.caption2.bold())
                        .foregroundColor(.orange)
                    }
                }

                if !item.recognizedText.isEmpty {
                    Text(item.recognizedText)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                }

                // Indicators row: links, QR, usernames
                HStack(spacing: 8) {
                    if !item.extractedLinks.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "link")
                            Text("\(item.extractedLinks.count)")
                        }
                        .font(.caption2)
                        .foregroundColor(.blue)
                    }

                    if !item.detectedQRCodes.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "qrcode")
                            Text("\(item.detectedQRCodes.count)")
                        }
                        .font(.caption2)
                        .foregroundColor(.purple)
                    }

                    if !item.detectedUsernames.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "at")
                            Text("\(item.detectedUsernames.count)")
                        }
                        .font(.caption2)
                        .foregroundColor(.green)
                    }

                    Spacer()
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 4)
        }
        .padding(8)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        .task {
            loadImage()
        }
    }

    private func loadImage() {
        if image == nil {
            self.image = ScreenshotObserver.shared.getImage(for: item)
        }
    }
}
