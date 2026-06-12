import Testing

@testable import SwiftPackageAuditCore

@Test
func checksResolvedPackageVersionsAgainstRemoteTags() {
    let checker = PackageVersionChecker(
        tagProvider: StubTagProvider(tags: [
            "1.0.0",
            "1.1.0",
            "v1.2.0",
            "1.2.1",
            "2.0.0",
            "2.0.0-beta.1",
        ])
    )

    let checks = checker.check(resolvedPackages: [
        ResolvedPackage(
            identity: "example",
            location: "https://github.com/example/example.git",
            version: "1.0.0"
        )
    ])

    #expect(checks.count == 1)
    #expect(checks.first?.latestVersion == "2.0.0")
    #expect(checks.first?.versionsBehind == 4)
    #expect(checks.first?.newerVersions == ["1.1.0", "1.2.0", "1.2.1", "2.0.0"])
    #expect(checks.first?.majorVersionsBehind == 1)
    #expect(checks.first?.minorVersionsBehind == 2)
    #expect(checks.first?.patchVersionsBehind == 0)
}

@Test
func scannerAddsOutdatedVersionDiagnosticWhenVersionCheckIsEnabled() {
    let scanner = SwiftPackageAuditScanner(
        versionChecker: StubVersionChecker(checks: [
            PackageVersionCheck(
                packageIdentity: "example",
                location: "https://github.com/example/example.git",
                currentVersion: "1.0.0",
                latestVersion: "1.2.0",
                versionsBehind: 2,
                newerVersions: ["1.1.0", "1.2.0"]
            )
        ])
    )

    let result = scanner.scan(
        configuration: ScanConfiguration(path: ".", checkVersions: true)
    )

    #expect(result.versionChecks.count == 1)
    #expect(result.diagnostics.contains { $0.rule == .outdatedVersion })
}

@Test
func scannerAnnotatesWhetherLatestVersionSatisfiesRequirement() throws {
    let root = try makeTemporaryDirectory()
    let project = root.appendingPathComponent("App.xcodeproj")
    try write(
        pbxproj(
            packageBlocks: packageReferenceBlock(
                url: "https://github.com/example/example.git",
                requirement: """
                  kind = upToNextMajorVersion;
                  minimumVersion = 1.0.0;
                """
            )
        ),
        to: project.appendingPathComponent("project.pbxproj")
    )
    try write(
        modernResolved(
            resolvedPin(
                identity: "example",
                location: "https://github.com/example/example.git",
                version: "1.0.0"
            )
        ),
        to: root.appendingPathComponent("Package.resolved")
    )

    let scanner = SwiftPackageAuditScanner(
        versionChecker: StubVersionChecker(checks: [
            PackageVersionCheck(
                packageIdentity: "example",
                location: "https://github.com/example/example.git",
                currentVersion: "1.0.0",
                latestVersion: "2.0.0",
                versionsBehind: 2,
                newerVersions: ["1.1.0", "2.0.0"]
            )
        ])
    )

    let result = scanner.scan(
        configuration: ScanConfiguration(path: root.path, checkVersions: true)
    )

    #expect(result.versionChecks.first?.requirementKind == "upToNextMajorVersion")
    #expect(result.versionChecks.first?.requirementValue == "1.0.0")
    #expect(result.versionChecks.first?.latestSatisfiesRequirement == false)
    #expect(result.versionChecks.first?.requirementNote?.contains("does not allow") == true)
    #expect(result.diagnostics.first { $0.rule == .outdatedVersion }?.message.contains("does not allow") == true)
}

private struct StubTagProvider: GitTagProviding {
    var tags: [String]

    func tags(for repositoryURL: String) throws -> [String] {
        tags
    }
}

private struct StubVersionChecker: PackageVersionChecking {
    var checks: [PackageVersionCheck]

    func check(resolvedPackages: [ResolvedPackage]) -> [PackageVersionCheck] {
        checks
    }
}
