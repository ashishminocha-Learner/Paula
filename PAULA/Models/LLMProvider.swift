import Foundation

enum LLMProvider: String, Codable, CaseIterable, Identifiable {
    case claude = "Claude"
    case gemini = "Gemini"
    case openai = "OpenAI"
    case groq   = "Groq"

    var id: String { rawValue }
}
