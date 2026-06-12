import Foundation
import Testing

@testable import SwiftPackageAuditCore

@Test
func baselineSuppressesMatchingDiagnostics() throws {
    let root = try makeTemporaryDirectory()
    let project = root.appendingPathComponent("MyApp.xcodeproj")
    try write(
        pbxproj(
            packageBlocks: packageReferenceBlock(
                url: "https://github.com/example/Branchy.git",
                requirement: """
                  kind = branch;
                  branch = main;
                """
            )
        ),
        to: project.appendingPathComponent("project.pbxproj")
    )
    try write(
        modernResolved(
            resolvedPin(
                identity: "branchy",
                location: "https://github.com/example/Branchy.git",
                branch: "main"
            )
        ),
        to: root.appendingPathComponent("Package.resolved")
    )

    let firstResult = SwiftPackageAuditScanner().scan(configuration: ScanConfiguration(path: root.path))
    let baselinePath = root.appendingPathComponent("SwiftPackageAuditBaseline.json").path
    try DiagnosticBaselineStore().write(
        DiagnosticBaseline(diagnostics: firstResult.diagnostics.map(BaselineEntry.init(diagnostic:))),
        path: baselinePath
    )

    let secondResult = SwiftPackageAuditScanner().scan(
        configuration: ScanConfiguration(path: root.path, baselinePath: baselinePath)
    )

    #expect(firstResult.diagnostics.contains { $0.rule == .branchDependency })
    #expect(!secondResult.diagnostics.contains { $0.rule == .branchDependency })
    #expect(secondResult.suppressedDiagnostics.contains { $0.rule == .branchDependency })
}

@Test
func baselineStoreRoundTripsBaselineJSON() throws {
    let root = try makeTemporaryDirectory()
    let path = root.appendingPathComponent("nested/SwiftPackageAuditBaseline.json").path
    let diagnostic = Diagnostic(
        rule: .packageReferencedButNotResolved,
        severity: .error,
        packageIdentity: "missing",
        projectPath: "/tmp/project/App.xcodeproj",
        message: "missing is not resolved."
    )
    let baseline = DiagnosticBaseline(
        generatedAt: "2026-06-12T12:00:00Z",
        diagnostics: [BaselineEntry(diagnostic: diagnostic)]
    )

    try DiagnosticBaselineStore().write(baseline, path: path)
    let loaded = try DiagnosticBaselineStore().load(path: path)

    #expect(loaded == baseline)
    #expect(loaded.diagnostics.first?.packageIdentity == "missing")
    #expect(loaded.diagnostics.first?.projectPath == "/tmp/project/App.xcodeproj")
    #expect(loaded.diagnostics.first?.message == "missing is not resolved.")
}

@Test
func baselineStoreReportsUnreadableInvalidAndUnwritableErrors() throws {
    let root = try makeTemporaryDirectory()
    let missingPath = root.appendingPathComponent("missing.json").path
    do {
        _ = try DiagnosticBaselineStore().load(path: missingPath)
        #expect(Bool(false))
    } catch DiagnosticBaselineError.unreadable(let path, let reason) {
        #expect(path == missingPath)
        #expect(!reason.isEmpty)
    }

    let invalidPath = root.appendingPathComponent("invalid.json").path
    try write("{", to: URL(fileURLWithPath: invalidPath))
    do {
        _ = try DiagnosticBaselineStore().load(path: invalidPath)
        #expect(Bool(false))
    } catch DiagnosticBaselineError.invalidJSON(let path, let reason) {
        #expect(path == invalidPath)
        #expect(!reason.isEmpty)
    }

    let unwritablePath = "/dev/null/SwiftPackageAuditBaseline.json"
    do {
        try DiagnosticBaselineStore().write(DiagnosticBaseline(), path: unwritablePath)
        #expect(Bool(false))
    } catch DiagnosticBaselineError.unwritable(let path, let reason) {
        #expect(path == unwritablePath)
        #expect(!reason.isEmpty)
    }
}
