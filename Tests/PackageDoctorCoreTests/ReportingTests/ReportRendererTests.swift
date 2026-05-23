import Testing

@testable import PackageDoctorCore

@Test
func rendersStableTextJSONAndMarkdownReports() throws {
    let result = WorkspaceScanResult(
        rootPath: "/tmp/project",
        projects: [ProjectScanResult(path: "/tmp/project/MyApp.xcodeproj")],
        resolvedPackages: [ResolvedPackage(identity: "lottie-spm", location: "https://github.com/airbnb/lottie-spm.git")],
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

    let text = try TextReportRenderer().render(result)
    let json = try JSONReportRenderer().render(result)
    let markdown = try MarkdownReportRenderer().render(result)

    #expect(text.contains("PackageDoctor"))
    #expect(text.contains("Warnings:"))
    #expect(json.contains("\"diagnostics\""))
    #expect(markdown.contains("| Severity | Rule | Package | Message | Suggestion |"))
}
