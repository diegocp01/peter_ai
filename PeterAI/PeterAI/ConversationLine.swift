import Foundation

struct ConversationLine: Identifiable, Equatable {
    enum Role: String, Equatable {
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

    let id = UUID()
    let role: Role
    let text: String
}
