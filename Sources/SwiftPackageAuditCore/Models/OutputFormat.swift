import Foundation

public enum OutputFormat: String, CaseIterable, Codable, Sendable {
    case text
    case json
    case markdown
    case prComment = "pr-comment"
}
