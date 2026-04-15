import Foundation
import SwiftData

@MainActor
final class RecordingDetailViewModel: ObservableObject {
    @Published var isTranscribing = false
    @Published var isSummarizing = false
    @Published var showRename = false
    @Published var renameText = ""
    @Published var showDeleteConfirm = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let transcriptionService = TranscriptionService()
    private let diarizationService = SpeakerDiarizationService()
    private let summaryService = SummaryService()
    private let actionItemService = ActionItemService()

    private var recording: RecordingModel?
    private var modelContext: ModelContext?

    func inject(recording: RecordingModel, modelContext: ModelContext) {
        self.recording = recording
        self.modelContext = modelContext
        renameText = recording.title
    }

    // MARK: - Transcription

    func transcribe() async {
        guard let recording, !isTranscribing else { return }
        isTranscribing = true
        defer { isTranscribing = false }

        do {
            let useWhisper = UserDefaults.standard.bool(forKey: "useWhisperAPI")
            let whisperKey = KeychainService.get(.whisperAPIKey)
            let result: TranscriptionResult
            if useWhisper && !whisperKey.isEmpty {
                await transcriptionService.setWhisperKey(whisperKey)
                result = try await transcriptionService.transcribeWithWhisper(url: recording.fileURL)
            } else {
                result = try await transcriptionService.transcribeOnDevice(url: recording.fileURL)
            }

            // Audio-enhanced speaker diarization (pitch + energy clustering)
            let labeled = await diarizationService.diarizeWithAudio(
                segments: result.segments,
                fileURL: recording.fileURL,
                speakerCount: 2
            )
            let turns = diarizationService.mergeIntoTurns(segments: labeled)

            // Persist transcript
            recording.rawTranscript = result.fullText
            for turn in turns {
                let segment = TranscriptSegmentModel(
                    speakerLabel: turn.speakerLabel,
                    text: turn.text,
                    startTime: turn.startTime,
                    endTime: turn.endTime
                )
                recording.segments.append(segment)
            }
            recording.isTranscribed = true
            try modelContext?.save()

            // Extract action items (on-device patterns + user cues, AI if key available)
            let actions = try? await actionItemService.extract(
                transcript: result.fullText,
                cues: recording.cues,
                speakers: turns
            )
            if let actions, !actions.isEmpty {
                recording.actionItemsJSON = actions.toJSON()
                try? modelContext?.save()
            }

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Summary

    func summarize() async {
        guard let recording, !isSummarizing else { return }
        guard let transcript = recording.rawTranscript, !transcript.isEmpty else {
            errorMessage = "No transcript available. Transcribe first."
            showError = true
            return
        }
        isSummarizing = true
        defer { isSummarizing = false }

        let template = recording.template ?? .meeting
        do {
            let summary = try await summaryService.summarize(transcript: transcript, template: template)
            recording.summary = summary
            recording.isSummarized = true
            try modelContext?.save()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Export

    func buildPDFExport() -> Data? {
        guard let recording else { return nil }
        let turns = recording.segments.map {
            SpeakerTurn(speakerLabel: $0.speakerLabel, text: $0.text,
                        startTime: $0.startTime, endTime: $0.endTime)
        }
        let content = PDFExporter.ExportContent(
            title: recording.title, date: recording.date,
            duration: recording.formattedDuration, transcript: turns,
            summary: recording.summary, template: recording.template
        )
        return PDFExporter().export(content: content)
    }

    func buildDOCXExport() -> Data? {
        guard let recording else { return nil }
        let turns = recording.segments.map {
            SpeakerTurn(speakerLabel: $0.speakerLabel, text: $0.text,
                        startTime: $0.startTime, endTime: $0.endTime)
        }
        let content = DOCXExporter.ExportContent(
            title: recording.title, date: recording.date,
            duration: recording.formattedDuration, transcript: turns,
            summary: recording.summary, template: recording.template
        )
        return try? DOCXExporter().export(content: content)
    }
}
