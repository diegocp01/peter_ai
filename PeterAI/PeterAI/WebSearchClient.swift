import Foundation

enum WebSearchError: LocalizedError {
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Could not read the web search response."
        case .apiError(let message):
            message
        }
    }
}

final class WebSearchClient {
    private let endpoint = URL(string: "https://api.openai.com/v1/responses")!
    private let model = "gpt-5.4-nano"

    func search(apiKey: String, query: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "input": """
            Search the web for this query and answer in a compact way for a spoken voice assistant.
            Include the most useful facts and source names. Query: \(query)
            """,
            "tools": [
                [
                    "type": "web_search_preview"
                ]
            ],
            "max_output_tokens": 700
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw WebSearchError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            throw WebSearchError.apiError(extractErrorMessage(from: data) ?? "OpenAI web search failed with HTTP \(http.statusCode).")
        }

        if let text = extractOutputText(from: data), !text.isEmpty {
            return text
        }

        throw WebSearchError.invalidResponse
    }

    private func extractOutputText(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let json = object as? [String: Any]
        else {
            return nil
        }

        if let outputText = json["output_text"] as? String {
            return outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let output = json["output"] as? [[String: Any]] else {
            return nil
        }

        let chunks = output.flatMap { item -> [String] in
            guard let content = item["content"] as? [[String: Any]] else { return [] }
            return content.compactMap { contentItem in
                contentItem["text"] as? String
            }
        }

        return chunks
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let json = object as? [String: Any],
            let error = json["error"] as? [String: Any]
        else {
            return nil
        }

        return error["message"] as? String
    }
}
