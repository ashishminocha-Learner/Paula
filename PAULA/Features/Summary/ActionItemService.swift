import Foundation

// MARK: - Action Item model

struct ActionItem: Codable, Identifiable, Sendable {
    let id: UUID
    let text: String           // the action itself
    let owner: String?         // person responsible, if detected
    let deadline: String?      // deadline string, if detected
    let confidence: Double     // 0–1, how confident we are this is an action
    let source: Source
    let cueTimestamp: Double?  // set if this came from a user cue

    enum Source: String, Codable {
        case ai       // detected by Claude
        case userCue  // user explicitly tapped "Action Item" cue
        case pattern  // caught by on-device regex
    }

    init(id: UUID = UUID(), text: String, owner: String? = nil, deadline: String? = nil,
         confidence: Double = 1.0, source: Source = .ai, cueTimestamp: Double? = nil) {
        self.id = id
        self.text = text
        self.owner = owner
        self.deadline = deadline
        self.confidence = confidence
        self.source = source
        self.cueTimestamp = cueTimestamp
    }
}

// MARK: - Action Item Service

actor ActionItemService {

    private func getClient() throws -> LLMClient {
        let providerStr = UserDefaults.standard.string(forKey: "llmProvider") ?? LLMProvider.claude.rawValue
        let provider = LLMProvider(rawValue: providerStr) ?? .claude
        
        switch provider {
        case .claude:
            return ClaudeClient(apiKey: KeychainService.get(.claudeAPIKey))
        case .gemini:
            return GeminiClient(apiKey: KeychainService.get(.geminiAPIKey))
        case .openai:
            return OpenAIClient(apiKey: KeychainService.get(.whisperAPIKey))
        case .groq:
            return GroqClient(apiKey: KeychainService.get(.groqAPIKey))
        }
    }

    /// Extract action items combining AI + user cues + on-device patterns.
    func extract(
        transcript: String,
        cues: [CueModel],
        speakers: [SpeakerTurn]
    ) async throws -> [ActionItem] {
        var items: [ActionItem] = []

        // 1. On-device pattern matching (free, instant, no API needed)
        items += onDevicePatterns(in: transcript, speakers: speakers)

        // 2. User-flagged cues
        items += cueBasedItems(cues: cues.filter { $0.type == .actionItem }, speakers: speakers)

        // 3. AI extraction
        if let aiItems = try? await aiExtract(transcript: transcript, cues: cues) {
            items += aiItems
        }

        // Deduplicate and sort by confidence
        return deduplicated(items).sorted { $0.confidence > $1.confidence }
    }

    // MARK: - On-device pattern matching

    private func onDevicePatterns(in transcript: String, speakers: [SpeakerTurn]) -> [ActionItem] {
        let patterns: [(pattern: String, confidence: Double)] = [
            (#"(?i)\b(I'?ll|I will|we will|we'?ll|let me|I need to|we need to|I should|we should)\s+(.{5,80})"#, 0.75),
            (#"(?i)\b(action item|follow up|follow-up|next step)\b[:\s]+(.{5,80})"#, 0.85),
            (#"(?i)\b(can you|could you|please)\s+(.{5,80})"#, 0.65),
            (#"(?i)\bby\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|tomorrow|next week|end of [a-z]+)\b(.{0,60})"#, 0.80),
            (#"(?i)\bdeadline[:\s]+(.{5,60})"#, 0.80),
        ]

        var items: [ActionItem] = []

        for (patternStr, confidence) in patterns {
            guard let regex = try? NSRegularExpression(pattern: patternStr) else { continue }
            let range = NSRange(transcript.startIndex..., in: transcript)
            let matches = regex.matches(in: transcript, range: range)

            for match in matches {
                // Grab the full match or the second capture group as the action text
                let captureRange = match.numberOfRanges > 2
                    ? match.range(at: 2)
                    : match.range(at: 0)
                guard let swiftRange = Range(captureRange, in: transcript) else { continue }
                let text = String(transcript[swiftRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                // Find which speaker said this
                let charOffset = transcript.distance(from: transcript.startIndex, to: swiftRange.lowerBound)
                let owner = speakerAt(charOffset: charOffset, in: speakers)

                items.append(ActionItem(text: text, owner: owner, confidence: confidence, source: .pattern))
            }
        }

        return items
    }

    // MARK: - Cue-based items

    private func cueBasedItems(cues: [CueModel], speakers: [SpeakerTurn]) -> [ActionItem] {
        cues.map { cue in
            // Find the speaker turn closest to the cue timestamp
            let nearestTurn = speakers.min(by: {
                abs($0.startTime - cue.timestamp) < abs($1.startTime - cue.timestamp)
            })
            let text = nearestTurn?.text ?? "User-flagged at \(cue.formattedTime)"
            return ActionItem(
                text: text,
                owner: nearestTurn?.speakerLabel,
                confidence: 1.0,   // user explicitly marked this
                source: .userCue,
                cueTimestamp: cue.timestamp
            )
        }
    }

    // MARK: - AI extraction

    private func aiExtract(transcript: String, cues: [CueModel]) async throws -> [ActionItem] {
        let cueContext = cues.isEmpty ? "" : """
        
        The user manually flagged these timestamps during recording:
        \(cues.map { "- [\($0.formattedTime)] \($0.type.label)" }.joined(separator: "\n"))
        Pay special attention to text near these timestamps.
        """
        
        let systemPrompt = """
        You are an expert at extracting action items from meeting transcripts.
        Extract every concrete commitment, task, request, or follow-up from the transcript.
        Return ONLY a valid JSON array. Each object must have:
          - "text": the action item (string)
          - "owner": speaker label or name if identifiable (string or null)
          - "deadline": any mentioned deadline (string or null)
          - "confidence": 0.0-1.0 float
        Example: [{"text":"Send the report","owner":"Speaker 1","deadline":"Friday","confidence":0.9}]
        Return [] if there are no action items. No explanation, no markdown, only JSON.
        """

        let userContent = "Transcript:\n\(transcript)\(cueContext)"
        
        let client = try getClient()
        let text = try await client.generate(systemPrompt: systemPrompt, userPrompt: userContent, maxTokens: 1024)
        
        return parseJSONResponse(text)
    }
    
    private func parseJSONResponse(_ text: String) -> [ActionItem] {
        // Strip markdown code block if model added it
        let cleanText = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonData = cleanText.data(using: .utf8) else { return [] }
        
        struct RawItem: Decodable {
            let text: String
            let owner: String?
            let deadline: String?
            let confidence: Double?
        }

        guard let raw = try? JSONDecoder().decode([RawItem].self, from: jsonData) else { return [] }
        return raw.map { ActionItem(text: $0.text, owner: $0.owner, deadline: $0.deadline, confidence: $0.confidence ?? 0.8, source: .ai) }
    }

    // MARK: - Helpers

    private func speakerAt(charOffset: Int, in speakers: [SpeakerTurn]) -> String? {
        // Rough approximation: assume text is evenly distributed across turns
        guard !speakers.isEmpty else { return nil }
        let totalChars = speakers.reduce(0) { $0 + $1.text.count }
        guard totalChars > 0 else { return nil }
        var accumulated = 0
        for turn in speakers {
            accumulated += turn.text.count
            if charOffset <= accumulated { return turn.speakerLabel }
        }
        return speakers.last?.speakerLabel
    }

    private func deduplicated(_ items: [ActionItem]) -> [ActionItem] {
        var seen: Set<String> = []
        return items.filter { item in
            let key = item.text.lowercased().prefix(40).description
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }
}

// MARK: - Persistence helpers

extension Array where Element == ActionItem {
    func toJSON() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func fromJSON(_ json: String) -> [ActionItem] {
        guard let data = json.data(using: .utf8),
              let items = try? JSONDecoder().decode([ActionItem].self, from: data) else { return [] }
        return items
    }
}

// Removed unused Key insertion
