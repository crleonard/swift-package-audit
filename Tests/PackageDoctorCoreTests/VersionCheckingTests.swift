import Testing

@testable import PackageDoctorCore

@Test
func checksResolvedPackageVersionsAgainstRemoteTags() {
    let checker = PackageVersionChecker(
        tagProvider: StubTagProvider(tags: [
            "1.0.0",
            "1.1.0",
            "v1.2.0",
            "1.2.1",
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
    #expect(checks.first?.latestVersion == "1.2.1")
    #expect(checks.first?.versionsBehind == 3)
    #expect(checks.first?.newerVersions == ["1.1.0", "1.2.0", "1.2.1"])
}

@Test
func scannerAddsOutdatedVersionDiagnosticWhenVersionCheckIsEnabled() {
    let scanner = PackageDoctorScanner(
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
