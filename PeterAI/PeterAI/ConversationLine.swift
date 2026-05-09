import Foundation

struct ConversationLine: Identifiable, Equatable, Codable {
    enum Role: String, Equatable, Codable {
        case user
        case assistant

        var title: String {
            switch self {
            case .user:
                "You"
            case .assistant:
                "Peter"
            }
        }
    }

    let id: UUID
    let role: Role
    let text: String

    init(id: UUID = UUID(), role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}
