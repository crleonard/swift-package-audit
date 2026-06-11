import Foundation

public protocol ReportRendering: Sendable {
    func render(_ result: WorkspaceScanResult) throws -> String
}

public struct TextReportRenderer: ReportRendering {
    public init() {}

    public func render(_ result: WorkspaceScanResult) -> String {
        var lines: [String] = [
            "PackageDoctor",
            "",
            "Path:",
            "  \(result.rootPath)",
            "",
            "Projects:",
        ]

        if result.projects.isEmpty {
            lines.append("  None")
        } else {
            lines.append(contentsOf: result.projects.map { "  \(URL(fileURLWithPath: $0.path).lastPathComponent)" })
        }

        let referencedCount = result.projects.flatMap(\.packageReferences).count
        lines += [
            "",
            "Swift packages:",
            "  \(referencedCount) referenced",
            "  \(result.resolvedPackages.count) resolved",
            "",
            "Health:",
            "  \(count(.info, in: result)) info",
            "  \(count(.warning, in: result)) warnings",
            "  \(count(.error, in: result)) errors",
            "  \(result.suppressedDiagnostics.count) suppressed",
        ]

        appendSection("Errors", severity: .error, result: result, lines: &lines)
        appendSection("Warnings", severity: .warning, result: result, lines: &lines)
        appendSection("Info", severity: .info, result: result, lines: &lines)
        appendVersionChecks(result.versionChecks, lines: &lines)

        return lines.joined(separator: "\n") + "\n"
    }

    private func appendSection(
        _ title: String,
        severity: DiagnosticSeverity,
        result: WorkspaceScanResult,
        lines: inout [String]
    ) {
        let diagnostics = result.diagnostics.filter { $0.severity == severity }
        guard !diagnostics.isEmpty else {
            return
        }

        lines += ["", "\(title):"]
        for diagnostic in diagnostics {
            let icon = icon(for: severity)
            let name = diagnostic.packageIdentity ?? diagnostic.rule.rawValue
            lines.append("  \(icon) \(name)")
            lines.append("     \(diagnostic.message)")
            if let suggestion = diagnostic.suggestion {
                lines.append("     Suggestion: \(suggestion)")
            }
        }
    }

    private func count(_ severity: DiagnosticSeverity, in result: WorkspaceScanResult) -> Int {
        result.diagnostics.filter { $0.severity == severity }.count
    }

    private func icon(for severity: DiagnosticSeverity) -> String {
        switch severity {
        case .info: "i"
        case .warning: "!"
        case .error: "x"
        }
    }

    private func appendVersionChecks(_ checks: [PackageVersionCheck], lines: inout [String]) {
        guard !checks.isEmpty else {
            return
        }

        lines += ["", "Version checks:"]
        for check in checks {
            if let error = check.error {
                lines.append("  ! \(check.packageIdentity)")
                lines.append("     Could not check \(check.currentVersion): \(error)")
            } else if let latestVersion = check.latestVersion, check.versionsBehind > 0 {
                lines.append("  ! \(check.packageIdentity)")
                lines.append(
                    """
                         Current: \(check.currentVersion), latest: \(latestVersion), \
                    \(check.versionsBehind) release tags behind \
                    (\(versionDistanceDescription(for: check))).
                    """
                )
                lines.append("     Newer versions: \(check.newerVersions.joined(separator: ", "))")
                if let requirementNote = check.requirementNote {
                    lines.append("     Requirement: \(requirementNote)")
                }
            } else {
                lines.append("  i \(check.packageIdentity)")
                lines.append("     Current: \(check.currentVersion), no newer release tags found.")
            }
        }
    }

    private func versionDistanceDescription(for check: PackageVersionCheck) -> String {
        let parts = [
            countDescription(check.majorVersionsBehind, singular: "major"),
            countDescription(check.minorVersionsBehind, singular: "minor"),
            countDescription(check.patchVersionsBehind, singular: "patch"),
        ].compactMap(\.self)

        return parts.isEmpty ? "0 classified releases" : parts.joined(separator: ", ")
    }

    private func countDescription(_ count: Int, singular: String) -> String? {
        guard count > 0 else {
            return nil
        }

        return "\(count) \(singular)"
    }
}

public struct JSONReportRenderer: ReportRendering {
    public init() {}

    public func render(_ result: WorkspaceScanResult) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(result)
        return (String(data: data, encoding: .utf8) ?? "") + "\n"
    }
}

public struct MarkdownReportRenderer: ReportRendering {
    public init() {}

    public func render(_ result: WorkspaceScanResult) -> String {
        var lines: [String] = [
            "## PackageDoctor",
            "",
            "**Path:** `\(result.rootPath)`",
            "",
            "| Severity | Rule | Package | Message | Suggestion |",
            "| --- | --- | --- | --- | --- |",
        ]

        if result.diagnostics.isEmpty {
            lines.append("| info | none |  | No dependency health issues found. |  |")
        } else {
            for diagnostic in result.diagnostics {
                let package = diagnostic.packageIdentity ?? ""
                let message = escape(diagnostic.message)
                let suggestion = escape(diagnostic.suggestion ?? "")
                let columns = [
                    diagnostic.severity.rawValue,
                    diagnostic.rule.rawValue,
                    package,
                    message,
                    suggestion,
                ]
                lines.append("| \(columns.joined(separator: " | ")) |")
            }
        }

        appendVersionChecks(result.versionChecks, lines: &lines)

        return lines.joined(separator: "\n") + "\n"
    }

    private func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func appendVersionChecks(_ checks: [PackageVersionCheck], lines: inout [String]) {
        guard !checks.isEmpty else {
            return
        }

        lines += [
            "",
            "### Version Checks",
            "",
            "| Package | Current | Latest | Behind | Distance | Requirement | Newer Versions |",
            "| --- | --- | --- | ---: | --- | --- | --- |",
        ]

        for check in checks {
            let columns = [
                check.packageIdentity,
                check.currentVersion,
                check.latestVersion ?? "-",
                "\(check.versionsBehind)",
                versionDistanceDescription(for: check),
                escape(check.requirementNote ?? "-"),
                escape(check.newerVersions.joined(separator: ", ")),
            ]
            lines.append("| \(columns.joined(separator: " | ")) |")
        }
    }

    private func versionDistanceDescription(for check: PackageVersionCheck) -> String {
        let parts = [
            countDescription(check.majorVersionsBehind, singular: "major"),
            countDescription(check.minorVersionsBehind, singular: "minor"),
            countDescription(check.patchVersionsBehind, singular: "patch"),
        ].compactMap(\.self)

        return parts.isEmpty ? "-" : parts.joined(separator: ", ")
    }

    private func countDescription(_ count: Int, singular: String) -> String? {
        guard count > 0 else {
            return nil
        }

        return "\(count) \(singular)"
    }
}

public struct PRCommentReportRenderer: ReportRendering {
    public init() {}

    public func render(_ result: WorkspaceScanResult) -> String {
        let errorCount = result.diagnostics.filter { $0.severity == .error }.count
        let warningCount = result.diagnostics.filter { $0.severity == .warning }.count
        let infoCount = result.diagnostics.filter { $0.severity == .info }.count
        var lines: [String] = [
            "## PackageDoctor",
            "",
            "| Errors | Warnings | Info | Suppressed |",
            "| ---: | ---: | ---: | ---: |",
            "| \(errorCount) | \(warningCount) | \(infoCount) | \(result.suppressedDiagnostics.count) |",
            "",
        ]

        if result.diagnostics.isEmpty {
            lines.append("No active dependency health issues found.")
        } else {
            lines.append("<details open>")
            lines.append("<summary>Dependency health findings</summary>")
            lines.append("")
            lines.append(contentsOf: markdownBody(for: result))
            lines.append("")
            lines.append("</details>")
        }

        if !result.suppressedDiagnostics.isEmpty {
            lines += [
                "",
                "<details>",
                "<summary>Suppressed by baseline</summary>",
                "",
            ]
            for diagnostic in result.suppressedDiagnostics {
                let package = diagnostic.packageIdentity.map { " \($0)" } ?? ""
                lines.append("- `\(diagnostic.rule.rawValue)`\(package): \(diagnostic.message)")
            }
            lines += ["", "</details>"]
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private func markdownBody(for result: WorkspaceScanResult) -> [String] {
        let lines = MarkdownReportRenderer().render(result)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
        return Array(lines.dropFirst(2))
    }
}

public enum ReportRendererFactory {
    public static func renderer(for format: OutputFormat) -> ReportRendering {
        switch format {
        case .text:
            TextReportRenderer()
        case .json:
            JSONReportRenderer()
        case .markdown:
            MarkdownReportRenderer()
        case .prComment:
            PRCommentReportRenderer()
        }
    }
}
