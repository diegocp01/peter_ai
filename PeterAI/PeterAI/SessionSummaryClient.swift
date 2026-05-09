import Foundation

struct SessionReport: Identifiable, Codable, Equatable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let duration: TimeInterval
    let wordCount: Int
    let transcript: String
    let statistics: SessionStatistics
    var summary: String
}

enum SessionSummaryError: LocalizedError {
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Could not read the session summary response."
        case .apiError(let message):
            message
        }
    }
}

final class SessionSummaryClient {
    private let model = "gpt-5.4-nano"

    func summarize(apiKey: String, transcript: String, duration: TimeInterval, wordCount: Int) async throws -> String {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else {
            return "No spoken transcript was captured."
        }

        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw SessionSummaryError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        Summarize this completed voice session for the user.

        Duration: \(formatDuration(duration))
        Word count: \(wordCount)

        Return this exact structure:

        Summary:
        One natural-language paragraph summarizing what happened in the session.

        Insights:
        Two or three short paragraphs with useful patterns, decisions, follow-up actions, emotional tone, or notable observations. Do not invent facts.

        Transcript:
        \(trimmedTranscript)
        """

        let payload: [String: Any] = [
            "model": model,
            "instructions": "You write post-session summaries for a personal voice companion app. Be factual, useful, and compact. Do not invent facts that are not in the transcript.",
            "input": prompt,
            "max_output_tokens": 420,
            "text": [
                "verbosity": "low"
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SessionSummaryError.apiError(extractErrorMessage(from: data) ?? "OpenAI summary request failed with HTTP \(http.statusCode).")
        }

        if let text = extractOutputText(from: data), !text.isEmpty {
            return text
        }

        if let issue = extractIncompleteMessage(from: data) {
            throw SessionSummaryError.apiError(issue)
        }

        throw SessionSummaryError.invalidResponse
    }

    private func extractOutputText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let outputText = json["output_text"] as? String {
            return outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let output = json["output"] {
            let chunks = collectOutputText(from: output)
            let joined = chunks.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty {
                return joined
            }
        }

        return nil
    }

    private func collectOutputText(from value: Any) -> [String] {
        if let string = value as? String {
            return [string]
        }

        if let array = value as? [Any] {
            return array.flatMap { collectOutputText(from: $0) }
        }

        guard let dictionary = value as? [String: Any] else {
            return []
        }

        if let type = dictionary["type"] as? String,
           ["reasoning", "summary", "annotation"].contains(type) {
            return []
        }

        var chunks: [String] = []
        if let text = dictionary["text"] {
            chunks.append(contentsOf: collectOutputText(from: text))
        }
        if let outputText = dictionary["output_text"] {
            chunks.append(contentsOf: collectOutputText(from: outputText))
        }
        if let content = dictionary["content"] {
            chunks.append(contentsOf: collectOutputText(from: content))
        }
        if let message = dictionary["message"] {
            chunks.append(contentsOf: collectOutputText(from: message))
        }

        return chunks
    }

    private func extractIncompleteMessage(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let status = json["status"] as? String,
            status != "completed"
        else {
            return nil
        }

        if let details = json["incomplete_details"] as? [String: Any],
           let reason = details["reason"] as? String {
            return "OpenAI summary response was incomplete: \(reason)."
        }

        return "OpenAI summary response was \(status)."
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = json["error"] as? [String: Any]
        else {
            return nil
        }

        return error["message"] as? String
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration.rounded()))
        let minutes = total / 60
        let seconds = total % 60
        return "\(minutes)m \(seconds)s"
    }
}
