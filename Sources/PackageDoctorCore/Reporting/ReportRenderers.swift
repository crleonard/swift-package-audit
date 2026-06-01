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
        ]

        appendSection("Errors", severity: .error, result: result, lines: &lines)
        appendSection("Warnings", severity: .warning, result: result, lines: &lines)
        appendSection("Info", severity: .info, result: result, lines: &lines)

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

        return lines.joined(separator: "\n") + "\n"
    }

    private func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
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
        }
    }
}
