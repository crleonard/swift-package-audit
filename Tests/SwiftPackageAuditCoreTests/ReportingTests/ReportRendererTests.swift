import Testing

@testable import SwiftPackageAuditCore

@Test
func rendersStableTextJSONAndMarkdownReports() throws {
    let result = WorkspaceScanResult(
        rootPath: "/tmp/project",
        projects: [ProjectScanResult(path: "/tmp/project/MyApp.xcodeproj")],
        resolvedPackages: [
            ResolvedPackage(identity: "lottie-spm", location: "https://github.com/airbnb/lottie-spm.git")
        ],
        diagnostics: [
            Diagnostic(
                rule: .branchDependency,
                severity: .warning,
                packageIdentity: "lottie-spm",
                message: "lottie-spm is pinned to branch 'main'.",
                suggestion: "Prefer a versioned release for reproducible builds."
            )
        ]
    )

    let text = TextReportRenderer().render(result)
    let json = try JSONReportRenderer().render(result)
    let markdown = MarkdownReportRenderer().render(result)

    #expect(text.contains("Swift Package Audit"))
    #expect(text.contains("Warnings:"))
    #expect(json.contains("\"diagnostics\""))
    #expect(markdown.contains("| Severity | Rule | Package | Message | Suggestion |"))
}

@Test
func rendersEmptyReportsWithoutDiagnostics() {
    let result = WorkspaceScanResult(rootPath: "/tmp/empty")

    let text = TextReportRenderer().render(result)
    let markdown = MarkdownReportRenderer().render(result)
    let prComment = PRCommentReportRenderer().render(result)

    #expect(text.contains("Projects:\n  None"))
    #expect(text.contains("0 suppressed"))
    #expect(markdown.contains("No dependency health issues found."))
    #expect(prComment.contains("No active dependency health issues found."))
    #expect(!prComment.contains("<summary>Dependency health findings</summary>"))
}

@Test
func rendersAllTextDiagnosticSections() {
    let result = WorkspaceScanResult(
        rootPath: "/tmp/project",
        diagnostics: [
            Diagnostic(rule: .missingPackageResolved, severity: .error, message: "Missing pins"),
            Diagnostic(
                rule: .branchDependency,
                severity: .warning,
                packageIdentity: "branchy",
                message: "Branch dependency",
                suggestion: "Use a release"
            ),
            Diagnostic(
                rule: .exactVersionDependency,
                severity: .info,
                packageIdentity: "exact",
                message: "Exact version"
            ),
        ]
    )

    let report = TextReportRenderer().render(result)

    #expect(report.contains("Errors:\n  x missingPackageResolved"))
    #expect(report.contains("Warnings:\n  ! branchy"))
    #expect(report.contains("Info:\n  i exact"))
    #expect(report.contains("Suggestion: Use a release"))
}

@Test
func rendersVersionCheckStatesInTextAndMarkdown() {
    let result = WorkspaceScanResult(
        rootPath: "/tmp/project",
        versionChecks: [
            PackageVersionCheck(
                packageIdentity: "current",
                location: "https://github.com/example/current.git",
                currentVersion: "1.0.0"
            ),
            PackageVersionCheck(
                packageIdentity: "behind",
                location: "https://github.com/example/behind.git",
                currentVersion: "1.0.0",
                latestVersion: "1.2.1",
                versionsBehind: 2,
                newerVersions: ["1.1.0", "1.2.1"],
                requirementNote: "The existing range allows the latest version.",
                minorVersionsBehind: 1,
                patchVersionsBehind: 1
            ),
            PackageVersionCheck(
                packageIdentity: "failed",
                location: "https://github.com/example/failed.git",
                currentVersion: "1.0.0",
                error: "network unavailable"
            ),
        ]
    )

    let text = TextReportRenderer().render(result)
    let markdown = MarkdownReportRenderer().render(result)

    #expect(text.contains("Current: 1.0.0, no newer release tags found."))
    #expect(text.contains("Current: 1.0.0, latest: 1.2.1, 2 release tags behind"))
    #expect(text.contains("Requirement: The existing range allows the latest version."))
    #expect(text.contains("Could not check 1.0.0: network unavailable"))
    #expect(markdown.contains("### Version Checks"))
    #expect(markdown.contains("| behind | 1.0.0 | 1.2.1 | 2 | 1 minor, 1 patch |"))
}

@Test
func markdownEscapesPipesAndNewlines() {
    let result = WorkspaceScanResult(
        rootPath: "/tmp/project",
        versionChecks: [
            PackageVersionCheck(
                packageIdentity: "odd",
                location: "https://github.com/example/odd.git",
                currentVersion: "1.0.0",
                latestVersion: "1.1.0",
                versionsBehind: 1,
                newerVersions: ["1.1.0 | renamed"],
                requirementNote: "Line | one\nline two"
            )
        ],
        diagnostics: [
            Diagnostic(
                rule: .parseError,
                severity: .warning,
                packageIdentity: "odd",
                message: "First | second\nthird",
                suggestion: "Use | safely"
            )
        ]
    )

    let markdown = MarkdownReportRenderer().render(result)

    #expect(markdown.contains("First \\| second third"))
    #expect(markdown.contains("Use \\| safely"))
    #expect(markdown.contains("Line \\| one line two"))
    #expect(markdown.contains("1.1.0 \\| renamed"))
}

@Test
func rendersPRCommentReport() throws {
    let result = WorkspaceScanResult(
        rootPath: "/tmp/project",
        diagnostics: [
            Diagnostic(
                rule: .missingPackageResolved,
                severity: .error,
                message: "Missing Package.resolved"
            )
        ],
        suppressedDiagnostics: [
            Diagnostic(
                rule: .branchDependency,
                severity: .warning,
                packageIdentity: "branchy",
                message: "branchy is pinned to branch 'main'."
            )
        ]
    )

    let report = PRCommentReportRenderer().render(result)

    #expect(report.contains("| Errors | Warnings | Info | Suppressed |"))
    #expect(report.contains("<summary>Dependency health findings</summary>"))
    #expect(report.contains("<summary>Suppressed by baseline</summary>"))
}

@Test
func jsonIncludesSchemaVersionAndDiagnosticIDs() throws {
    let result = WorkspaceScanResult(
        rootPath: "/tmp/project",
        diagnostics: [
            Diagnostic(
                rule: .missingPackageResolved,
                severity: .error,
                message: "Missing Package.resolved"
            )
        ]
    )

    let json = try JSONReportRenderer().render(result)

    #expect(json.contains("\"schemaVersion\" : 1"))
    #expect(json.contains("\"id\""))
}
