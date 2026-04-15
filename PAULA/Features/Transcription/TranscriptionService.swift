import AVFoundation
import Foundation
import Speech

/// A single transcribed segment produced by the transcription pipeline.
struct TranscribedSegment: Sendable {
    let text: String
    let startTime: Double
    let endTime: Double
    let confidence: Double
    var speakerLabel: String = "Speaker 1"
}

/// Result of a full transcription pass.
struct TranscriptionResult: Sendable {
    let segments: [TranscribedSegment]
    let fullText: String
    let language: String
}

// MARK: - Transcription Service

/// Transcribes audio using Apple's on-device SFSpeechRecognizer.
/// Falls back to OpenAI Whisper API when configured (better accuracy / more languages).
actor TranscriptionService {

    // MARK: Config

    /// When non-nil, Whisper API is used instead of on-device recognition.
    var whisperAPIKey: String?

    func setWhisperKey(_ key: String) {
        whisperAPIKey = key
    }

    // MARK: On-device transcription

    /// Transcribe an audio file using SFSpeechRecognizer (on-device, free, works offline).
    func transcribeOnDevice(url: URL, locale: Locale = .current) async throws -> TranscriptionResult {
        if SFSpeechRecognizer.authorizationStatus() != .authorized {
            let status = await requestSpeechPermission()
            guard status == .authorized else {
                throw TranscriptionError.permissionDenied
            }
        }

        guard let recognizer = SFSpeechRecognizer(locale: locale)
                ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = false
        request.taskHint = .dictation

        // Use a nonisolated-safe continuation; the callback runs on an internal
        // SFSpeechRecognizer queue, so we capture only Sendable values.
        let capturedLocale = locale.identifier
        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !resumed else { return }
                if let error {
                    resumed = true
                    continuation.resume(throwing: TranscriptionError.recognitionFailed(error))
                    return
                }
                guard let result, result.isFinal else { return }
                resumed = true
                var segments: [TranscribedSegment] = []
                for segment in result.bestTranscription.segments {
                    segments.append(TranscribedSegment(
                        text: segment.substring,
                        startTime: segment.timestamp,
                        endTime: segment.timestamp + segment.duration,
                        confidence: Double(segment.confidence)
                    ))
                }
                continuation.resume(returning: TranscriptionResult(
                    segments: segments,
                    fullText: result.bestTranscription.formattedString,
                    language: capturedLocale
                ))
            }
        }
    }

    // MARK: Whisper API transcription

    /// Transcribe using OpenAI Whisper API. Requires `whisperAPIKey` to be set.
    /// Audio is uploaded to OpenAI's servers — user must consent to this.
    func transcribeWithWhisper(url: URL, language: String? = nil) async throws -> TranscriptionResult {
        guard let apiKey = whisperAPIKey, !apiKey.isEmpty else {
            throw TranscriptionError.apiKeyMissing
        }

        let data = try Data(contentsOf: url)
        let boundary = UUID().uuidString
        var body = Data()

        // model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\nwhisper-1\r\n".data(using: .utf8)!)

        // response_format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\nverbose_json\r\n".data(using: .utf8)!)

        // language (optional)
        if let language {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n\(language)\r\n".data(using: .utf8)!)
        }

        // timestamp_granularities
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"timestamp_granularities[]\"\r\n\r\nword\r\n".data(using: .utf8)!)

        // file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        guard let whisperURL = URL(string: "https://api.openai.com/v1/audio/transcriptions") else {
            throw TranscriptionError.networkError("Invalid Whisper API URL")
        }
        var request = URLRequest(url: whisperURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 120

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw TranscriptionError.apiError(String(data: responseData, encoding: .utf8) ?? "Unknown error")
        }

        let whisperResponse = try JSONDecoder().decode(WhisperVerboseResponse.self, from: responseData)
        let segments: [TranscribedSegment] = (whisperResponse.words ?? []).map {
            TranscribedSegment(text: $0.word, startTime: $0.start, endTime: $0.end, confidence: 1.0)
        }
        return TranscriptionResult(
            segments: segments,
            fullText: whisperResponse.text,
            language: whisperResponse.language ?? "unknown"
        )
    }

    // MARK: - Helpers

    private func requestSpeechPermission() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

// MARK: - Errors

enum TranscriptionError: LocalizedError {
    case permissionDenied
    case recognizerUnavailable
    case recognitionFailed(Error)
    case apiKeyMissing
    case apiError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:          return "Speech recognition permission denied."
        case .recognizerUnavailable:     return "Speech recognizer is not available for this language."
        case .recognitionFailed(let e):  return "Recognition failed: \(e.localizedDescription)"
        case .apiKeyMissing:             return "OpenAI API key is not configured."
        case .apiError(let msg):         return "Whisper API error: \(msg)"
        case .networkError(let msg):     return "Network error: \(msg)"
        }
    }
}

// MARK: - Whisper API response models

private struct WhisperVerboseResponse: Decodable {
    let text: String
    let language: String?
    let words: [WhisperWord]?
}

private struct WhisperWord: Decodable {
    let word: String
    let start: Double
    let end: Double
}
