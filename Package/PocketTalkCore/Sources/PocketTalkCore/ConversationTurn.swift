import Foundation

/// One message in a conversation. Roles follow the chat-completion convention.
public struct ConversationTurn: Codable, Equatable, Hashable, Sendable {
    public enum Role: String, Codable, Sendable, CaseIterable {
        case system
        case user
        case assistant
    }

    public var role: Role
    public var text: String

    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }

    public static func system(_ text: String) -> ConversationTurn {
        ConversationTurn(role: .system, text: text)
    }

    public static func user(_ text: String) -> ConversationTurn {
        ConversationTurn(role: .user, text: text)
    }

    public static func assistant(_ text: String) -> ConversationTurn {
        ConversationTurn(role: .assistant, text: text)
    }
}
