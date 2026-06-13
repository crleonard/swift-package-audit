import Foundation

public enum DiagnosticSeverity: String, Codable, Comparable, Sendable {
    case info
    case warning
    case error

    public static func < (lhs: DiagnosticSeverity, rhs: DiagnosticSeverity) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .info: 0
        case .warning: 1
        case .error: 2
        }
    }
}
