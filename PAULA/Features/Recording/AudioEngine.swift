import AVFoundation
import Combine
import Foundation

/// Errors that can occur during audio recording.
enum AudioEngineError: LocalizedError {
    case sessionSetupFailed(Error)
    case recorderSetupFailed(Error)
    case noPermission
    case recordingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .sessionSetupFailed(let e): return "Audio session error: \(e.localizedDescription)"
        case .recorderSetupFailed(let e): return "Recorder setup failed: \(e.localizedDescription)"
        case .noPermission: return "Microphone access was denied. Please enable it in Settings."
        case .recordingFailed(let e): return "Recording failed: \(e.localizedDescription)"
        }
    }
}

/// State of the audio engine.
enum RecordingState {
    case idle, recording, paused, stopped
}

/// Core audio recording engine. Thread-safe via MainActor.
@MainActor
final class AudioEngine: NSObject, ObservableObject {

    // MARK: - Published state

    @Published private(set) var state: RecordingState = .idle
    @Published private(set) var currentLevel: Float = 0        // 0.0 – 1.0
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var error: AudioEngineError?

    // MARK: - Private

    private var recorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var elapsedTimer: Timer?
    private var recordingStartDate: Date?
    private var pauseAccumulated: TimeInterval = 0
    private var pauseStartDate: Date?
    private var darwinListenerRegistered = false

    // MARK: - Public API

    /// Request microphone permission.
    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    /// Start a new recording. Returns the file URL on success.
    @discardableResult
    func startRecording(fileName: String) async throws -> URL {
        guard state == .idle || state == .stopped else {
            guard let url = recorder?.url else {
                throw AudioEngineError.recordingFailed(
                    NSError(domain: "AudioEngine", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Recording already in progress."]))
            }
            return url
        }

        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else { throw AudioEngineError.noPermission }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord,
                                    mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw AudioEngineError.sessionSetupFailed(error)
        }

        let url = documentsURL(fileName: fileName)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128_000
        ]

        do {
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.delegate = self
            rec.isMeteringEnabled = true
            rec.record()
            self.recorder = rec
        } catch {
            throw AudioEngineError.recorderSetupFailed(error)
        }

        state = .recording
        recordingStartDate = Date()
        pauseAccumulated = 0
        startTimers()
        pushWidgetState()
        registerDarwinListener()

        return url
    }

    func pauseRecording() {
        guard state == .recording else { return }
        recorder?.pause()
        pauseStartDate = Date()
        pauseAccumulated = elapsedTime
        stopTimers()
        state = .paused
        pushWidgetState()
    }

    func resumeRecording() {
        guard state == .paused else { return }
        recorder?.record()
        pauseStartDate = nil
        recordingStartDate = Date()
        startTimers()
        state = .recording
        pushWidgetState()
    }

    /// Stop recording and return the final duration.
    @discardableResult
    func stopRecording() -> TimeInterval {
        guard state == .recording || state == .paused else { return 0 }
        let finalDuration = elapsedTime
        recorder?.stop()
        stopTimers()
        state = .idle
        recordingStartDate = nil
        pauseAccumulated = 0
        elapsedTime = 0
        deactivateSession()
        WidgetBridge.clearState()
        return finalDuration
    }

    // MARK: - Private helpers

    private func startTimers() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateLevel()
            }
        }
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateElapsed()
            }
        }
    }

    private func stopTimers() {
        levelTimer?.invalidate(); levelTimer = nil
        elapsedTimer?.invalidate(); elapsedTimer = nil
        currentLevel = 0
    }

    private func updateLevel() {
        guard let rec = recorder, rec.isRecording else { return }
        rec.updateMeters()
        // AVAudioRecorder returns dBFS in range ~ -160 to 0
        let dB = rec.averagePower(forChannel: 0)
        let normalized = max(0, (dB + 60) / 60)   // map -60…0 dBFS → 0…1
        currentLevel = normalized
    }

    private func updateElapsed() {
        guard let start = recordingStartDate else { return }
        elapsedTime = pauseAccumulated + Date().timeIntervalSince(start)
    }

    private func documentsURL(fileName: String) -> URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
            .appendingPathExtension("m4a")
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false,
                                                        options: .notifyOthersOnDeactivation)
    }

    // MARK: - Widget bridge

    /// Called by RecordingViewModel when a cue is dropped, to update widget counter.
    func pushMarkCount(_ count: Int) {
        pushWidgetState(markCount: count)
    }

    /// Push current recording state to the App Group so the widget can read it.
    private func pushWidgetState(markCount: Int = 0) {
        WidgetBridge.updateState(
            isRecording:   state == .recording || state == .paused,
            isPaused:      state == .paused,
            startDate:     recordingStartDate,
            pausedElapsed: pauseAccumulated,
            markCount:     markCount
        )
    }

    /// Register a Darwin notification listener so widget button taps wake this engine.
    /// Guard against duplicate registration across multiple recording sessions.
    private func registerDarwinListener() {
        guard !darwinListenerRegistered else { return }
        darwinListenerRegistered = true
        let name = WidgetBridge.darwinNotifName as CFString
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),   // unretained — no leak
            { _, observer, _, _, _ in
                guard let ptr = observer else { return }
                let engine = Unmanaged<AudioEngine>.fromOpaque(ptr).takeUnretainedValue()
                Task { @MainActor in engine.handleWidgetAction() }
            },
            name, nil,
            .deliverImmediately
        )
    }

    /// Called when a Darwin notification arrives from the widget.
    /// Routes through NotificationCenter so RecordingViewModel handles
    /// all actions — including the SwiftData insert on stop.
    func handleWidgetAction() {
        guard let action = WidgetBridge.consumePendingAction() else { return }
        let name: String
        switch action {
        case .mark:  name = "mark"
        case .pause: name = "pause"
        case .stop:  name = "stop"
        }
        NotificationCenter.default.post(name: .paulaWidgetAction, object: name)
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioEngine: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            Task { @MainActor in
                self.error = .recordingFailed(
                    NSError(domain: "AudioEngine", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Recording ended unexpectedly."])
                )
                self.state = .stopped
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        guard let error else { return }
        Task { @MainActor in
            self.error = .recordingFailed(error)
        }
    }
}
