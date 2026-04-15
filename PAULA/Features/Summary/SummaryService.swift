import Foundation

// MARK: - Summary Service

/// Calls the Anthropic Claude API to generate structured summaries.
actor SummaryService {

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

    /// Generate a summary for the given transcript using the specified template.
    func summarize(transcript: String, template: SummaryTemplate) async throws -> String {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SummaryError.emptyTranscript
        }

        let client = try getClient()
        return try await client.generate(systemPrompt: template.systemPrompt, userPrompt: transcript, maxTokens: 2048)
    }

    /// Generate a concise title for a recording from the first few lines of transcript.
    func generateTitle(transcript: String) async throws -> String {
        let snippet = String(transcript.prefix(500))
        let prompt = """
        Given the start of this transcript, generate a short title (5 words or fewer) that describes the conversation.
        Reply with only the title, no quotes or punctuation at the end.
        Transcript: \(snippet)
        """

        let client = try getClient()
        do {
            let title = try await client.generate(systemPrompt: "You are a helpful title generator.", userPrompt: prompt, maxTokens: 30)
            return title.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return "Recording \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))"
        }
    }
}

// MARK: - Errors

enum SummaryError: LocalizedError {
    case apiKeyMissing
    case emptyTranscript
    case emptyResponse
    case networkError(String)
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "Claude API key is not configured. Add it in Settings."
        case .emptyTranscript:
            return "Cannot summarize an empty transcript."
        case .emptyResponse:
            return "Claude returned an empty response."
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .apiError(let code, let body):
            return "API error \(code): \(body)"
        }
    }
}

// Removed Anthropic models
