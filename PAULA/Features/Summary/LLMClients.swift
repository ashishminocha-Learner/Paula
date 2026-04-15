import Foundation

// MARK: - Core LLM Protocol

protocol LLMClient: Sendable {
    func generate(systemPrompt: String, userPrompt: String, maxTokens: Int) async throws -> String
}

enum LLMError: LocalizedError {
    case missingKey
    case invalidResponse
    case apiError(Int, String)
    case localModelError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingKey: return "API key is missing. Please configure it in Settings."
        case .invalidResponse: return "The model returned an invalid or empty response."
        case .apiError(let code, let msg): return "API Error \(code): \(msg)"
        case .localModelError(let msg): return "Local Model Error: \(msg)"
        }
    }
}

// MARK: - Claude Client

struct ClaudeClient: LLMClient {
    let apiKey: String
    
    func generate(systemPrompt: String, userPrompt: String, maxTokens: Int) async throws -> String {
        guard !apiKey.isEmpty else { throw LLMError.missingKey }
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        
        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": maxTokens,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userPrompt]]
        ]
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw LLMError.invalidResponse }
        guard http.statusCode == 200 else {
            throw LLMError.apiError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        
        struct Resp: Decodable { let content: [Block] }
        struct Block: Decodable { let text: String }
        
        guard let decoded = try? JSONDecoder().decode(Resp.self, from: data),
              let text = decoded.content.first?.text else {
            throw LLMError.invalidResponse
        }
        return text
    }
}

// MARK: - Gemini Client

struct GeminiClient: LLMClient {
    let apiKey: String
    
    func generate(systemPrompt: String, userPrompt: String, maxTokens: Int) async throws -> String {
        guard !apiKey.isEmpty else { throw LLMError.missingKey }
        // Using gemini-1.5-flash for speed/cost balance
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw LLMError.invalidResponse }
        
        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                ["role": "user", "parts": [["text": userPrompt]]]
            ],
            "generationConfig": [
                "maxOutputTokens": maxTokens
            ]
        ]
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw LLMError.invalidResponse }
        guard http.statusCode == 200 else {
            throw LLMError.apiError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        
        struct GeminiResp: Decodable { let candidates: [Candidate]? }
        struct Candidate: Decodable { let content: Content? }
        struct Content: Decodable { let parts: [Part]? }
        struct Part: Decodable { let text: String? }
        
        guard let decoded = try? JSONDecoder().decode(GeminiResp.self, from: data),
              let text = decoded.candidates?.first?.content?.parts?.first?.text else {
            throw LLMError.invalidResponse
        }
        return text
    }
}

// MARK: - Groq Client

struct GroqClient: LLMClient {
    let apiKey: String

    func generate(systemPrompt: String, userPrompt: String, maxTokens: Int) async throws -> String {
        guard !apiKey.isEmpty else { throw LLMError.missingKey }
        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!

        let body: [String: Any] = [
            "model": "llama-3.3-70b-versatile",   // fast, high-quality Groq model
            "max_tokens": maxTokens,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": userPrompt]
            ]
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw LLMError.invalidResponse }
        guard http.statusCode == 200 else {
            throw LLMError.apiError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        // Groq uses OpenAI-compatible response format
        struct GroqResp: Decodable { let choices: [Choice] }
        struct Choice:   Decodable { let message: Message }
        struct Message:  Decodable { let content: String }

        guard let decoded = try? JSONDecoder().decode(GroqResp.self, from: data) else {
            throw LLMError.invalidResponse
        }
        return decoded.choices.first?.message.content ?? ""
    }
}

// MARK: - OpenAI Client

struct OpenAIClient: LLMClient {
    let apiKey: String
    
    func generate(systemPrompt: String, userPrompt: String, maxTokens: Int) async throws -> String {
        guard !apiKey.isEmpty else { throw LLMError.missingKey }
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "max_tokens": maxTokens,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ]
        ]
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw LLMError.invalidResponse }
        guard http.statusCode == 200 else {
            throw LLMError.apiError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        
        struct OAIResp: Decodable { let choices: [Choice] }
        struct Choice: Decodable { let message: Message }
        struct Message: Decodable { let content: String }
        
        guard let decoded = try? JSONDecoder().decode(OAIResp.self, from: data) else {
            throw LLMError.invalidResponse
        }
        return decoded.choices.first?.message.content ?? ""
    }
}
