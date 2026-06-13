import Foundation

public struct Diagnostic: Codable, Equatable, Sendable {
    public var id: String
    public var rule: DiagnosticRule
    public var severity: DiagnosticSeverity
    public var packageIdentity: String?
    public var projectPath: String?
    public var message: String
    public var suggestion: String?

    public init(
        rule: DiagnosticRule,
        severity: DiagnosticSeverity,
        packageIdentity: String? = nil,
        projectPath: String? = nil,
        message: String,
        suggestion: String? = nil
    ) {
        self.id = Diagnostic.makeID(
            rule: rule,
            packageIdentity: packageIdentity,
            projectPath: projectPath,
            message: message
        )
        self.rule = rule
        self.severity = severity
        self.packageIdentity = packageIdentity
        self.projectPath = projectPath
        self.message = message
        self.suggestion = suggestion
    }

    public static func makeID(
        rule: DiagnosticRule,
        packageIdentity: String?,
        projectPath: String?,
        message: String
    ) -> String {
        [
            rule.rawValue,
            packageIdentity?.lowercased() ?? "",
            URL(fileURLWithPath: projectPath ?? "").lastPathComponent.lowercased(),
            message.normalizedDiagnosticText,
        ].joined(separator: "|").stableSwiftPackageAuditHash
    }
}
