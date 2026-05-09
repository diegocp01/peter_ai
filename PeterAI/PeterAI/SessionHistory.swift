import Foundation
import NaturalLanguage

struct SessionStatistics: Codable, Equatable {
    let totalWords: Int
    let userWords: Int
    let assistantWords: Int
    let totalTurns: Int
    let userTurns: Int
    let assistantTurns: Int
    let wordsPerMinute: Double
    let averageWordsPerTurn: Double
    let longestTurnWords: Int
    let sentimentScore: Double?

    var sentimentLabel: String {
        guard let sentimentScore else { return "Not enough text" }
        switch sentimentScore {
        case 0.25...:
            return "Positive"
        case ...(-0.25):
            return "Negative"
        default:
            return "Neutral"
        }
    }
}

enum SessionAnalytics {
    static func build(lines: [ConversationLine], userDraft: String, assistantDraft: String, duration: TimeInterval) -> (transcript: String, statistics: SessionStatistics) {
        var entries = lines.map { ($0.role, $0.text.trimmingCharacters(in: .whitespacesAndNewlines)) }

        let user = userDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let assistant = assistantDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !user.isEmpty {
            entries.append((.user, user))
        }
        if !assistant.isEmpty {
            entries.append((.assistant, assistant))
        }

        let transcript = entries
            .filter { !$0.1.isEmpty }
            .map { "\($0.0.title): \($0.1)" }
            .joined(separator: "\n")

        let userTexts = entries.filter { $0.0 == .user }.map { $0.1 }
        let assistantTexts = entries.filter { $0.0 == .assistant }.map { $0.1 }
        let turnWordCounts = entries.map { countWords(in: $0.1) }
        let totalWords = turnWordCounts.reduce(0, +)
        let minutes = max(duration / 60, 1.0 / 60.0)

        let statistics = SessionStatistics(
            totalWords: totalWords,
            userWords: userTexts.map { countWords(in: $0) }.reduce(0, +),
            assistantWords: assistantTexts.map { countWords(in: $0) }.reduce(0, +),
            totalTurns: entries.count,
            userTurns: userTexts.count,
            assistantTurns: assistantTexts.count,
            wordsPerMinute: Double(totalWords) / minutes,
            averageWordsPerTurn: entries.isEmpty ? 0 : Double(totalWords) / Double(entries.count),
            longestTurnWords: turnWordCounts.max() ?? 0,
            sentimentScore: sentimentScore(for: userTexts.joined(separator: "\n"))
        )

        return (transcript, statistics)
    }

    private static func countWords(in text: String) -> Int {
        text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .count
    }

    private static func sentimentScore(for text: String) -> Double? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        let (tag, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        return tag.flatMap { Double($0.rawValue) }
    }
}

enum SessionStore {
    private static let key = "PeterAI.savedSessions.v1"
    private static let activeKey = "PeterAI.activeSession.v1"

    struct ActiveCheckpoint: Codable {
        let id: UUID
        let startedAt: Date
        let lastUpdatedAt: Date
        let lines: [ConversationLine]
    }

    static func load() -> [SessionReport] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let sessions = try? JSONDecoder().decode([SessionReport].self, from: data)
        else {
            return []
        }

        return sessions.sorted { $0.startedAt > $1.startedAt }
    }

    static func save(_ sessions: [SessionReport]) {
        let sorted = sessions.sorted { $0.startedAt > $1.startedAt }
        guard let data = try? JSONEncoder().encode(sorted) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func upsert(_ report: SessionReport, into sessions: [SessionReport]) -> [SessionReport] {
        var updated = sessions.filter { $0.id != report.id }
        updated.append(report)
        updated.sort { $0.startedAt > $1.startedAt }
        save(updated)
        return updated
    }

    static func saveActiveCheckpoint(id: UUID, startedAt: Date, lines: [ConversationLine]) {
        let checkpoint = ActiveCheckpoint(id: id, startedAt: startedAt, lastUpdatedAt: Date(), lines: lines)
        guard let data = try? JSONEncoder().encode(checkpoint) else { return }
        UserDefaults.standard.set(data, forKey: activeKey)
    }

    static func clearActiveCheckpoint() {
        UserDefaults.standard.removeObject(forKey: activeKey)
    }

    static func recoverInterruptedSession(into sessions: [SessionReport]) -> [SessionReport] {
        guard
            let data = UserDefaults.standard.data(forKey: activeKey),
            let checkpoint = try? JSONDecoder().decode(ActiveCheckpoint.self, from: data)
        else {
            return sessions
        }

        clearActiveCheckpoint()

        let endedAt = checkpoint.lastUpdatedAt
        let duration = endedAt.timeIntervalSince(checkpoint.startedAt)
        let snapshot = SessionAnalytics.build(lines: checkpoint.lines, userDraft: "", assistantDraft: "", duration: duration)
        let report = SessionReport(
            id: checkpoint.id,
            startedAt: checkpoint.startedAt,
            endedAt: endedAt,
            duration: duration,
            wordCount: snapshot.statistics.totalWords,
            transcript: snapshot.transcript,
            statistics: snapshot.statistics,
            summary: snapshot.transcript.isEmpty
                ? "PeterAI was closed while a session was active. No spoken transcript was captured before the app closed."
                : "PeterAI was closed while this session was active, so the local transcript and statistics were saved without an LLM summary."
        )

        return upsert(report, into: sessions)
    }
}
