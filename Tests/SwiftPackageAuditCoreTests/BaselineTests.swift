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
