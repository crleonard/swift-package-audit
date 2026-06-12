import Foundation

public struct SwiftPackageAuditConfig: Codable, Equatable, Sendable {
    public var failOn: [DiagnosticRule]
    public var allowedBranchDependencies: [String]
    public var ignoredPackages: [String]
    public var ignoredRules: [DiagnosticRule]
    public var requirePackageResolved: Bool
    public var allowExactVersions: Bool

    public init(
        failOn: [DiagnosticRule] = [],
        allowedBranchDependencies: [String] = [],
        ignoredPackages: [String] = [],
        ignoredRules: [DiagnosticRule] = [],
        requirePackageResolved: Bool = true,
        allowExactVersions: Bool = false
    ) {
        self.failOn = failOn
        self.allowedBranchDependencies = allowedBranchDependencies
        self.ignoredPackages = ignoredPackages
        self.ignoredRules = ignoredRules
        self.requirePackageResolved = requirePackageResolved
        self.allowExactVersions = allowExactVersions
    }
}

public enum SwiftPackageAuditConfigError: Error, CustomStringConvertible, Sendable {
    case unreadable(String, String)
    case invalidRule(String)

    public var description: String {
        switch self {
        case .unreadable(let path, let reason):
            "Could not read config at \(path): \(reason)"
        case .invalidRule(let value):
            "Unknown diagnostic rule in config: \(value)"
        }
    }
}

public struct SwiftPackageAuditConfigLoader: Sendable {
    public init() {}

    public func load(path: String) throws -> SwiftPackageAuditConfig {
        let contents: String
        do {
            contents = try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw SwiftPackageAuditConfigError.unreadable(path, error.localizedDescription)
        }
        return try parse(contents)
    }

    public func parse(_ contents: String) throws -> SwiftPackageAuditConfig {
        var config = SwiftPackageAuditConfig()
        var section: [String] = []

        for rawLine in contents.components(separatedBy: .newlines) {
            let line = rawLine.withoutComment
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else {
                continue
            }

            let indent = line.prefix { $0 == " " }.count
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasSuffix(":") {
                let key = String(trimmed.dropLast())
                if indent == 0 {
                    section = [key]
                } else if indent <= 2 {
                    section = [section.first, key].compactMap(\.self)
                }
                continue
            }

            if trimmed.hasPrefix("- ") {
                let value = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                try applyListValue(value, section: section, config: &config)
                continue
            }

            if let separator = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: separator)...])
                    .trimmingCharacters(in: .whitespaces)
                applyScalarValue(value, key: key, section: section, config: &config)
            }
        }

        return config
    }

    private func applyListValue(
        _ value: String,
        section: [String],
        config: inout SwiftPackageAuditConfig
    ) throws {
        switch section {
        case ["failOn"]:
            config.failOn.append(try rule(from: value))
        case ["allow", "branchDependencies"]:
            config.allowedBranchDependencies.append(value)
        case ["ignore", "packages"]:
            config.ignoredPackages.append(value)
        case ["ignore", "rules"]:
            config.ignoredRules.append(try rule(from: value))
        default:
            break
        }
    }

    private func applyScalarValue(
        _ value: String,
        key: String,
        section: [String],
        config: inout SwiftPackageAuditConfig
    ) {
        guard section == ["rules"] else {
            return
        }

        switch key {
        case "requirePackageResolved":
            config.requirePackageResolved = value.yamlBoolValue ?? config.requirePackageResolved
        case "allowExactVersions":
            config.allowExactVersions = value.yamlBoolValue ?? config.allowExactVersions
        default:
            break
        }
    }

    private func rule(from value: String) throws -> DiagnosticRule {
        guard let rule = DiagnosticRule(rawValue: value) else {
            throw SwiftPackageAuditConfigError.invalidRule(value)
        }
        return rule
    }
}

private extension String {
    var withoutComment: String {
        guard let index = firstIndex(of: "#") else {
            return self
        }
        return String(self[..<index])
    }

    var yamlBoolValue: Bool? {
        switch lowercased() {
        case "true", "yes":
            true
        case "false", "no":
            false
        default:
            nil
        }
    }
}
