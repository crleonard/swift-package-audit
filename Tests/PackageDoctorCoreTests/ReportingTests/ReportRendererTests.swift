import Testing

@testable import PackageDoctorCore

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

    #expect(text.contains("PackageDoctor"))
    #expect(text.contains("Warnings:"))
    #expect(json.contains("\"diagnostics\""))
    #expect(markdown.contains("| Severity | Rule | Package | Message | Suggestion |"))
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
