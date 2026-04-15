import Testing
@testable import PAULA

@Suite("SpeakerDiarizationService")
struct SpeakerDiarizationTests {

    @Test("Single speaker — no changes")
    func singleSpeaker() {
        let service = SpeakerDiarizationService()
        let segments = [
            TranscribedSegment(text: "Hello", startTime: 0, endTime: 0.5, confidence: 1.0),
            TranscribedSegment(text: "world", startTime: 0.6, endTime: 1.0, confidence: 1.0)
        ]
        let turns = service.mergeIntoTurns(segments: service.diarize(segments: segments))
        #expect(turns.count == 1)
        #expect(turns[0].speakerLabel == "Speaker 1")
    }

    @Test("Long pause triggers speaker change")
    func longPauseTriggersSpeakerChange() {
        var service = SpeakerDiarizationService()
        service.hardSplitThreshold = 2.0
        let segments = [
            TranscribedSegment(text: "Hello", startTime: 0, endTime: 1, confidence: 1.0),
            TranscribedSegment(text: "Goodbye", startTime: 5, endTime: 6, confidence: 1.0)
        ]
        let labeled = service.diarize(segments: segments)
        let turns = service.mergeIntoTurns(segments: labeled)
        #expect(turns.count == 2)
    }

    @Test("Merge consecutive same-speaker segments")
    func mergeSameSpeaker() {
        let service = SpeakerDiarizationService()
        let segments = [
            TranscribedSegment(text: "One", startTime: 0, endTime: 0.5, confidence: 1.0),
            TranscribedSegment(text: "two", startTime: 0.6, endTime: 1.0, confidence: 1.0),
            TranscribedSegment(text: "three", startTime: 1.1, endTime: 1.5, confidence: 1.0)
        ]
        let turns = service.mergeIntoTurns(segments: service.diarize(segments: segments))
        #expect(turns[0].text == "One two three")
    }
}

@Suite("SummaryTemplate")
struct SummaryTemplateTests {
    @Test("All templates have non-empty system prompts")
    func promptsAreNonEmpty() {
        for template in SummaryTemplate.allCases {
            #expect(!template.systemPrompt.isEmpty)
        }
    }

    @Test("rawValue round-trips correctly")
    func rawValueRoundTrip() {
        for template in SummaryTemplate.allCases {
            #expect(SummaryTemplate(rawValue: template.rawValue) == template)
        }
    }
}
