import Foundation

public struct DiagnosticBaseline: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var generatedAt: String
    public var diagnostics: [BaselineEntry]

    public init(
        schemaVersion: Int = 1,
        generatedAt: String = ISO8601DateFormatter().string(from: Date()),
        diagnostics: [BaselineEntry] = []
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.diagnostics = diagnostics
    }
}

public struct BaselineEntry: Codable, Equatable, Sendable {
    public var id: String
    public var rule: DiagnosticRule
    public var severity: DiagnosticSeverity
    public var packageIdentity: String?
    public var projectPath: String?
    public var message: String

    public init(diagnostic: Diagnostic) {
        id = diagnostic.id
        rule = diagnostic.rule
        severity = diagnostic.severity
        packageIdentity = diagnostic.packageIdentity
        projectPath = diagnostic.projectPath
        message = diagnostic.message
    }
}

public enum DiagnosticBaselineError: Error, CustomStringConvertible, Sendable {
    case unreadable(String, String)
    case invalidJSON(String, String)
    case unwritable(String, String)

    public var description: String {
        switch self {
        case .unreadable(let path, let reason):
            "Could not read baseline at \(path): \(reason)"
        case .invalidJSON(let path, let reason):
            "Could not parse baseline at \(path): \(reason)"
        case .unwritable(let path, let reason):
            "Could not write baseline at \(path): \(reason)"
        }
    }
}

public struct DiagnosticBaselineStore: Sendable {
    public init() {}

    public func load(path: String) throws -> DiagnosticBaseline {
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            throw DiagnosticBaselineError.unreadable(path, error.localizedDescription)
        }

        do {
            return try JSONDecoder().decode(DiagnosticBaseline.self, from: data)
        } catch {
            throw DiagnosticBaselineError.invalidJSON(path, error.localizedDescription)
        }
    }

    public func write(_ baseline: DiagnosticBaseline, path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(baseline)
        let url = URL(fileURLWithPath: path)

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
        } catch {
            throw DiagnosticBaselineError.unwritable(path, error.localizedDescription)
        }
    }
}
