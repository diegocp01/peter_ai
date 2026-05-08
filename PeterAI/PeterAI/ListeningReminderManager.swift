import Foundation
import UserNotifications

final class ListeningReminderManager {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func sendReminder(body: String) {
        let content = UNMutableNotificationContent()
        content.title = "PeterAI"
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: "peterai-listening-\(UUID().uuidString)", content: content, trigger: nil)
        center.add(request)
    }
}

enum TenWordSummary {
    static func make(from text: String) -> String {
        let words = text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let meaningful = words.filter { word in
            !stopWords.contains(word.lowercased())
        }

        let selected = Array((meaningful.isEmpty ? words : meaningful).suffix(10))
        guard !selected.isEmpty else {
            return "Still listening; no new speech captured in this window lately."
        }

        return selected.joined(separator: " ")
    }

    private static let stopWords: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "but", "by",
        "for", "from", "i", "in", "is", "it", "me", "my",
        "of", "on", "or", "so", "that", "the", "this", "to",
        "was", "we", "were", "with", "you", "your"
    ]
}
