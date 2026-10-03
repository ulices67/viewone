import SwiftUI

public struct AppTagBadge: View {
    public let app: SourceApp

    public init(app: SourceApp) {
        self.app = app
    }

    public var body: some View {
        HStack(spacing: 5) {
            Image(systemName: app.iconName)
                .font(.caption2.weight(.bold))
            Text(app.rawValue)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(app.brandColor.opacity(0.15))
        .foregroundColor(app.brandColor)
        .clipShape(Capsule())
    }
}
