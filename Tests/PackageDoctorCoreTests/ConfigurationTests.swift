import Testing

@testable import PackageDoctorCore

@Test
func parsesPackageDoctorConfig() throws {
    let config = try PackageDoctorConfigLoader().parse(
        """
        failOn:
          - missingPackageResolved
          - branchDependency

        allow:
          branchDependencies:
            - InternalDesignSystem

        ignore:
          packages:
            - LegacyPackage
          rules:
            - exactVersionDependency

        rules:
          requirePackageResolved: false
          allowExactVersions: true
        """
    )

    #expect(config.failOn == [.missingPackageResolved, .branchDependency])
    #expect(config.allowedBranchDependencies == ["InternalDesignSystem"])
    #expect(config.ignoredPackages == ["LegacyPackage"])
    #expect(config.ignoredRules == [.exactVersionDependency])
    #expect(config.requirePackageResolved == false)
    #expect(config.allowExactVersions == true)
}

@Test
func configSuppressesAllowedDiagnosticsDuringScan() throws {
    let root = try makeTemporaryDirectory()
    let project = root.appendingPathComponent("MyApp.xcodeproj")
    try write(
        pbxproj(
            packageBlocks: packageReferenceBlock(
                url: "https://github.com/example/InternalDesignSystem.git",
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
                identity: "internaldesignsystem",
                location: "https://github.com/example/InternalDesignSystem.git",
                branch: "main"
            )
        ),
        to: root.appendingPathComponent("Package.resolved")
    )
    try write(
        """
        allow:
          branchDependencies:
            - internaldesignsystem
        """,
        to: root.appendingPathComponent("PackageDoctor.yml")
    )

    let result = PackageDoctorScanner().scan(configuration: ScanConfiguration(path: root.path))

    #expect(!result.diagnostics.contains { $0.rule == .branchDependency })
}
