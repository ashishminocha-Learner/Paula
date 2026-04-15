import Combine
import Foundation
import SwiftData
import UIKit

@MainActor
final class RecordingViewModel: ObservableObject {

    @Published var selectedTemplate: SummaryTemplate = .meeting
    @Published var showingTemplateSheet = false
    @Published var alertMessage: String?
    @Published var showAlert = false

    let engine = AudioEngine()
    private var modelContext: ModelContext?
    private var currentFileName: String?
    private var currentRecording: RecordingModel?
    private var cancellables = Set<AnyCancellable>()

    init() {
        engine.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Handle widget button taps (paula:// URL scheme → NotificationCenter)
        NotificationCenter.default.publisher(for: .paulaWidgetAction)
            .compactMap { $0.object as? String }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] action in
                guard let self else { return }
                switch action {
                case "mark":  self.dropCue(.bookmark)
                case "pause":
                    if self.isRecording   { self.pauseRecording() }
                    else if self.isPaused { self.resumeRecording() }
                case "stop":
                    if self.isRecording || self.isPaused { self.stopRecording() }
                default: break
                }
            }
            .store(in: &cancellables)
    }

    func inject(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var state: RecordingState { engine.state }
    var level: Float { engine.currentLevel }
    var elapsed: TimeInterval { engine.elapsedTime }
    var isRecording: Bool { engine.state == .recording }
    var isPaused: Bool { engine.state == .paused }

    func startRecording() async {
        let fileName = "recording_\(Date().timeIntervalSince1970)_\(UUID().uuidString.prefix(8))"
        currentFileName = fileName
        do {
            let url = try await engine.startRecording(fileName: fileName)
            let relativePath = url.lastPathComponent
            // Keep in memory only — inserted into the store when recording stops
            // so it never appears in the Library while still recording.
            let recording = RecordingModel(
                title: "Recording \(Date().formatted(date: .abbreviated, time: .shortened))",
                filePath: relativePath
            )
            recording.template = selectedTemplate
            currentRecording = recording
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    func pauseRecording() {
        engine.pauseRecording()
    }

    func resumeRecording() {
        engine.resumeRecording()
    }

    // MARK: - Cues

    var currentMarkCount: Int { currentRecording?.cues.count ?? 0 }

    func dropCue(_ type: CueType) {
        guard isRecording, let recording = currentRecording else { return }
        let cue = CueModel(type: type, timestamp: elapsed)
        recording.cues.append(cue)
        objectWillChange.send()
        // Keep widget mark counter in sync
        engine.pushMarkCount(recording.cues.count)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Called by the widget bridge when a mark action arrives from the lock screen.
    func handleWidgetMark() {
        dropCue(.bookmark)
    }

    func stopRecording() {
        let duration = engine.stopRecording()
        guard let recording = currentRecording else { return }
        recording.duration = duration
        // Insert now so it only appears in the Library once recording is complete
        modelContext?.insert(recording)
        do {
            try modelContext?.save()
        } catch {
            alertMessage = "Recording saved but duration could not be stored: \(error.localizedDescription)"
            showAlert = true
        }
        currentRecording = nil
    }
}
