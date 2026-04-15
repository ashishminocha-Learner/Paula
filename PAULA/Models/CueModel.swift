import Foundation
import SwiftData

// MARK: - Cue type

enum CueType: String, CaseIterable, Codable, Identifiable {
    case goodPoint  = "good_point"
    case actionItem = "action_item"
    case question   = "question"
    case idea       = "idea"
    case bookmark   = "bookmark"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .goodPoint:  return "Good Point"
        case .actionItem: return "Action Item"
        case .question:   return "Question"
        case .idea:       return "Idea"
        case .bookmark:   return "Mark"
        }
    }

    var icon: String {
        switch self {
        case .goodPoint:  return "hand.thumbsup.fill"
        case .actionItem: return "checkmark.circle.fill"
        case .question:   return "questionmark.circle.fill"
        case .idea:       return "lightbulb.fill"
        case .bookmark:   return "bookmark.fill"
        }
    }

    var color: String {
        switch self {
        case .goodPoint:  return "green"
        case .actionItem: return "blue"
        case .question:   return "orange"
        case .idea:       return "purple"
        case .bookmark:   return "gray"
        }
    }

    /// SwiftUI color name, usable with Color(cueType.color)
    var swiftUIColor: String { color }
}

// MARK: - SwiftData model

@Model
final class CueModel {
    var id: UUID
    var typeRawValue: String
    var timestamp: Double      // seconds into the recording
    var note: String?

    init(type: CueType, timestamp: Double, note: String? = nil) {
        self.id = UUID()
        self.typeRawValue = type.rawValue
        self.timestamp = timestamp
        self.note = note
    }

    var type: CueType {
        CueType(rawValue: typeRawValue) ?? .bookmark
    }

    var formattedTime: String {
        let t = Int(timestamp)
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}
