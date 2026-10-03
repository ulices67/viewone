import Foundation
import SwiftUI

public enum SourceApp: String, CaseIterable, Codable, Identifiable {
    case instagram = "Instagram"
    case whatsApp = "WhatsApp"
    case tikTok = "TikTok"
    case safari = "Safari"
    case xTwitter = "X"
    case telegram = "Telegram"
    case youtube = "YouTube"
    case notes = "Notas"
    case unknown = "General"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .instagram: return "camera.fill"
        case .whatsApp: return "message.fill"
        case .tikTok: return "music.note"
        case .safari: return "safari.fill"
        case .xTwitter: return "bubble.left.and.bubble.right.fill"
        case .telegram: return "paperplane.fill"
        case .youtube: return "play.rectangle.fill"
        case .notes: return "note.text"
        case .unknown: return "photo.fill"
        }
    }

    public var brandColor: Color {
        switch self {
        case .instagram: return Color.pink
        case .whatsApp: return Color.green
        case .tikTok: return Color.cyan
        case .safari: return Color.blue
        case .xTwitter: return Color.primary
        case .telegram: return Color.indigo
        case .youtube: return Color.red
        case .notes: return Color.orange
        case .unknown: return Color.gray
        }
    }
}
