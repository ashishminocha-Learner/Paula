import Foundation

enum SummaryTemplate: String, CaseIterable, Identifiable, Codable {
    case meeting = "meeting"
    case interview = "interview"
    case lecture = "lecture"
    case brainstorm = "brainstorm"
    case salesCall = "sales_call"
    case oneOnOne = "one_on_one"
    case general = "general"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .meeting:     return "Meeting"
        case .interview:   return "Interview"
        case .lecture:     return "Lecture / Class"
        case .brainstorm:  return "Brainstorm"
        case .salesCall:   return "Sales Call"
        case .oneOnOne:    return "1-on-1"
        case .general:     return "General"
        }
    }

    var icon: String {
        switch self {
        case .meeting:     return "person.3.fill"
        case .interview:   return "person.fill.questionmark"
        case .lecture:     return "graduationcap.fill"
        case .brainstorm:  return "lightbulb.fill"
        case .salesCall:   return "phone.fill.arrow.up.right"
        case .oneOnOne:    return "person.2.fill"
        case .general:     return "doc.text.fill"
        }
    }

    var systemPrompt: String {
        let base = """
        You are an expert note-taker and summarizer. Analyze the transcript below and produce a structured summary.
        Be concise, accurate, and use the speaker labels if present.
        Transcript:
        """
        let format: String
        switch self {
        case .meeting:
            format = """
            Structure your output with these sections:
            ## Summary
            2-3 sentence overview.
            ## Key Decisions
            Bullet list of decisions made.
            ## Action Items
            Bullet list with owner name (if identifiable) and action.
            ## Discussion Points
            Main topics discussed.
            """
        case .interview:
            format = """
            Structure your output:
            ## Candidate / Interviewee Overview
            Who was interviewed and for what.
            ## Key Strengths
            Bullet list.
            ## Areas of Concern
            Bullet list.
            ## Notable Quotes
            Direct quotes worth remembering.
            ## Recommendation
            A brief hiring or follow-up recommendation.
            """
        case .lecture:
            format = """
            Structure your output:
            ## Topic
            What was covered.
            ## Key Concepts
            Numbered list of main ideas.
            ## Examples & Analogies
            Any examples used.
            ## Summary
            2-3 sentence recap.
            ## Follow-up Questions
            Questions worth exploring.
            """
        case .brainstorm:
            format = """
            Structure your output:
            ## Problem / Goal
            What was being brainstormed.
            ## Ideas Generated
            Bullet list of all ideas.
            ## Top Ideas
            3 most promising ideas with brief reasoning.
            ## Next Steps
            Agreed next steps.
            """
        case .salesCall:
            format = """
            Structure your output:
            ## Contact & Context
            Who was on the call and their role/company.
            ## Pain Points
            Customer problems identified.
            ## Interest Level
            Assessment of interest/fit.
            ## Objections
            Concerns raised and responses.
            ## Next Steps
            Agreed follow-up actions with dates if mentioned.
            """
        case .oneOnOne:
            format = """
            Structure your output:
            ## Participants
            Who was on the call.
            ## Updates Shared
            Key updates from each person.
            ## Blockers & Concerns
            Issues raised.
            ## Action Items
            Follow-ups with owners.
            ## Morale / Sentiment
            Overall tone of the conversation.
            """
        case .general:
            format = """
            Structure your output:
            ## Summary
            2-3 sentence overview.
            ## Key Points
            Bullet list of main takeaways.
            ## Action Items
            Any follow-ups mentioned.
            """
        }
        return "\(base)\n\n\(format)"
    }
}
