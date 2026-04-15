import Foundation
import SwiftData

@Model
final class RecordingModel {
    var id: UUID
    var title: String
    var date: Date
    var duration: TimeInterval
    /// Relative path from the app's Documents directory
    var filePath: String
    var isTranscribed: Bool
    var isSummarized: Bool
    var templateRawValue: String?
    var summary: String?
    var rawTranscript: String?
    /// JSON-encoded [ActionItem] array
    var actionItemsJSON: String?

    @Relationship(deleteRule: .cascade)
    var segments: [TranscriptSegmentModel] = []

    @Relationship(deleteRule: .cascade)
    var cues: [CueModel] = []

    init(title: String, filePath: String) {
        self.id = UUID()
        self.title = title
        self.date = Date()
        self.duration = 0
        self.filePath = filePath
        self.isTranscribed = false
        self.isSummarized = false
    }

    var fileURL: URL {
        guard let docsURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first else {
            // Documents directory is guaranteed on iOS — this path is unreachable in practice
            preconditionFailure("Documents directory unavailable")
        }
        return docsURL.appendingPathComponent(filePath)
    }

    var formattedDuration: String {
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    var template: SummaryTemplate? {
        get { templateRawValue.flatMap { SummaryTemplate(rawValue: $0) } }
        set { templateRawValue = newValue?.rawValue }
    }
}

@Model
final class TranscriptSegmentModel {
    var id: UUID
    var speakerLabel: String
    var text: String
    var startTime: Double
    var endTime: Double
    var confidence: Double

    init(speakerLabel: String, text: String, startTime: Double, endTime: Double, confidence: Double = 1.0) {
        self.id = UUID()
        self.speakerLabel = speakerLabel
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
    }

    var formattedStartTime: String {
        let total = Int(startTime)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
