import Foundation

/// Groups raw word-level segments into speaker-labeled turns.
/// Uses pitch + energy clustering (AudioAnalyzer) when available,
/// falling back to pause-duration heuristics.
struct SpeakerDiarizationService {

    private let analyzer = AudioAnalyzer()

    /// Minimum silence gap (seconds) that triggers a potential speaker change.
    var silenceThreshold: Double = 1.2
    /// Minimum gap that forces a speaker change regardless of other factors.
    var hardSplitThreshold: Double = 3.0
    /// Maximum number of speaker labels to assign.
    var maxSpeakers: Int = 6

    /// Audio-enhanced diarization: extracts pitch + energy, clusters by speaker.
    /// Falls back to pause heuristic for segments with no detectable pitch.
    func diarizeWithAudio(
        segments: [TranscribedSegment],
        fileURL: URL,
        speakerCount: Int = 2
    ) async -> [TranscribedSegment] {
        // Always sort chronologically first so clustering sees time-ordered input
        let sorted = segments.sorted { $0.startTime < $1.startTime }
        let features = await analyzer.analyzeSegments(fileURL: fileURL, segments: sorted)
        guard !features.isEmpty else { return diarize(segments: sorted) }

        let clustered = analyzer.clusterSpeakers(features: features, k: speakerCount)

        // Remap cluster indices so the first speaker encountered chronologically
        // is always "Speaker 1", the second new voice is "Speaker 2", etc.
        var result = sorted
        var clusterToSpeaker: [Int: Int] = [:]
        var nextSpeakerIndex = 0
        for i in 0 ..< min(sorted.count, clustered.count) {
            let clusterIdx = clustered[i].speakerIndex
            guard clusterIdx >= 0 else { result[i].speakerLabel = "Speaker 1"; continue }
            if clusterToSpeaker[clusterIdx] == nil {
                clusterToSpeaker[clusterIdx] = nextSpeakerIndex
                nextSpeakerIndex += 1
            }
            result[i].speakerLabel = "Speaker \((clusterToSpeaker[clusterIdx] ?? 0) + 1)"
        }
        return result
    }

    /// Assign speaker labels to a flat list of word segments.
    func diarize(segments: [TranscribedSegment]) -> [TranscribedSegment] {
        // Sort chronologically before applying heuristics
        let segments = segments.sorted { $0.startTime < $1.startTime }
        guard !segments.isEmpty else { return [] }

        // Step 1: Group words into utterances by silence gaps
        var utterances: [[TranscribedSegment]] = []
        var current: [TranscribedSegment] = [segments[0]]

        for i in 1 ..< segments.count {
            let gap = segments[i].startTime - segments[i - 1].endTime
            if gap >= silenceThreshold {
                utterances.append(current)
                current = []
            }
            current.append(segments[i])
        }
        utterances.append(current)

        // Step 2: Assign speaker labels via alternating heuristic
        // In a typical 2-person conversation, speaker alternates at pauses.
        var speakerIndex = 0
        var lastSpeakerChangeTime: Double = segments[0].startTime
        var labeledSegments: [TranscribedSegment] = []

        for (idx, utterance) in utterances.enumerated() {
            guard let first = utterance.first else { continue }

            // Force a speaker change after a long silence
            if idx > 0 {
                let gapFromPrev = first.startTime - (utterances[idx - 1].last?.endTime ?? 0)
                if gapFromPrev >= hardSplitThreshold {
                    speakerIndex = (speakerIndex + 1) % min(maxSpeakers, 2)
                    lastSpeakerChangeTime = first.startTime
                } else if gapFromPrev >= silenceThreshold && first.startTime - lastSpeakerChangeTime > 5 {
                    // Alternate if speaker hasn't changed in a while
                    speakerIndex = (speakerIndex + 1) % min(maxSpeakers, 2)
                    lastSpeakerChangeTime = first.startTime
                }
            }

            let label = "Speaker \(speakerIndex + 1)"
            for segment in utterance {
                var labeled = segment
                labeled.speakerLabel = label
                labeledSegments.append(labeled)
            }
        }

        return labeledSegments
    }

    /// Merge consecutive word segments from the same speaker into turn-level segments.
    func mergeIntoTurns(segments: [TranscribedSegment]) -> [SpeakerTurn] {
        guard !segments.isEmpty else { return [] }

        var turns: [SpeakerTurn] = []
        var currentSpeaker = segments[0].speakerLabel
        var words: [String] = []
        var startTime = segments[0].startTime
        var endTime = segments[0].endTime

        for segment in segments {
            if segment.speakerLabel == currentSpeaker {
                words.append(segment.text)
                endTime = segment.endTime
            } else {
                turns.append(SpeakerTurn(
                    speakerLabel: currentSpeaker,
                    text: words.joined(separator: " "),
                    startTime: startTime,
                    endTime: endTime
                ))
                currentSpeaker = segment.speakerLabel
                words = [segment.text]
                startTime = segment.startTime
                endTime = segment.endTime
            }
        }
        turns.append(SpeakerTurn(
            speakerLabel: currentSpeaker,
            text: words.joined(separator: " "),
            startTime: startTime,
            endTime: endTime
        ))
        return turns
    }
}

// MARK: - Supporting types

struct SpeakerTurn: Identifiable, Sendable {
    let id = UUID()
    let speakerLabel: String
    let text: String
    let startTime: Double
    let endTime: Double

    var formattedTime: String {
        let total = Int(startTime)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

