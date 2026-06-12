import Foundation
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
func skipsPackagesWithoutValidCurrentVersions() {
    let checker = PackageVersionChecker(
        tagProvider: StubTagProvider(tags: ["1.0.0", "1.1.0"])
    )

    let checks = checker.check(resolvedPackages: [
        ResolvedPackage(identity: "branchy", location: "https://github.com/example/branchy.git"),
        ResolvedPackage(
            identity: "invalid",
            location: "https://github.com/example/invalid.git",
            version: "main"
        ),
        ResolvedPackage(
            identity: "valid",
            location: "https://github.com/example/valid.git",
            version: "1.0.0"
        ),
    ])

    #expect(checks.map(\.packageIdentity) == ["valid"])
}

@Test
func versionCheckerReportsTagProviderErrorsPerPackage() {
    let checker = PackageVersionChecker(tagProvider: ThrowingTagProvider())

    let checks = checker.check(resolvedPackages: [
        ResolvedPackage(
            identity: "example",
            location: "https://github.com/example/example.git",
            version: "1.0.0"
        )
    ])

    #expect(checks.count == 1)
    #expect(checks.first?.error == "remote tags unavailable")
    #expect(checks.first?.latestVersion == nil)
    #expect(checks.first?.versionsBehind == 0)
}

@Test
func versionCheckerDeduplicatesNormalizesAndIgnoresPrereleaseTags() {
    let checker = PackageVersionChecker(
        tagProvider: StubTagProvider(tags: [
            "v1.0.1",
            "1.0.1",
            "1.0.2-beta.1",
            "release-1.0.3",
            "1.1",
        ])
    )

    let checks = checker.check(resolvedPackages: [
        ResolvedPackage(
            identity: "example",
            location: "https://github.com/example/example.git",
            version: "1.0"
        )
    ])

    #expect(checks.first?.currentVersion == "1.0")
    #expect(checks.first?.newerVersions == ["1.0.1", "1.1.0"])
    #expect(checks.first?.latestVersion == "1.1.0")
    #expect(checks.first?.versionsBehind == 2)
    #expect(checks.first?.minorVersionsBehind == 1)
    #expect(checks.first?.patchVersionsBehind == 1)
}

@Test
func semanticVersionParsesAndOrdersStableVersions() {
    #expect(SemanticVersion("v1.2") == SemanticVersion(major: 1, minor: 2, patch: 0))
    #expect(SemanticVersion("1.2.3")! < SemanticVersion("1.3.0")!)
    #expect(SemanticVersion("1.2.3-beta.1") == nil)
    #expect(SemanticVersion("release-1.2.3") == nil)
}

@Test
func gitRemoteTagProviderReadsTagsFromLocalRepository() throws {
    let root = try makeTemporaryDirectory()
    try runGit(["init"], in: root)
    try runGit(["config", "user.email", "tests@example.com"], in: root)
    try runGit(["config", "user.name", "Swift Package Audit Tests"], in: root)
    try write("fixture", to: root.appendingPathComponent("README.md"))
    try runGit(["add", "README.md"], in: root)
    try runGit(["commit", "-m", "Initial commit"], in: root)
    try runGit(["tag", "1.0.0"], in: root)
    try runGit(["tag", "v1.1.0"], in: root)

    let tags = try GitRemoteTagProvider(timeoutSeconds: 5).tags(for: root.absoluteString)

    #expect(tags.contains("1.0.0"))
    #expect(tags.contains("v1.1.0"))
}

@Test
func gitRemoteTagProviderReportsGitFailures() throws {
    let missingRepository = try makeTemporaryDirectory().appendingPathComponent("missing.git")

    do {
        _ = try GitRemoteTagProvider(timeoutSeconds: 5).tags(for: missingRepository.absoluteString)
        #expect(Bool(false))
    } catch VersionCheckError.gitFailed(let message) {
        #expect(!message.isEmpty)
    }
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

private enum StubTagError: Error, LocalizedError {
    case unavailable

    var errorDescription: String? {
        "remote tags unavailable"
    }
}

private struct ThrowingTagProvider: GitTagProviding {
    func tags(for repositoryURL: String) throws -> [String] {
        throw StubTagError.unavailable
    }
}

private func runGit(_ arguments: [String], in directory: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["git"] + arguments
    process.currentDirectoryURL = directory
    process.standardOutput = Pipe()
    process.standardError = Pipe()
    try process.run()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)
}

private struct StubVersionChecker: PackageVersionChecking {
    var checks: [PackageVersionCheck]

    func check(resolvedPackages: [ResolvedPackage]) -> [PackageVersionCheck] {
        checks
    }
}
