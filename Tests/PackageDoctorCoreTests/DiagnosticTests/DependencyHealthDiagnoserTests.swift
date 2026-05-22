import Testing

@testable import PackageDoctorCore

@Test
func reportsMissingPackageResolvedWhenProjectHasReferences() {
    let project = ProjectScanResult(
        path: "/tmp/MyApp.xcodeproj",
        packageReferences: [
            PackageReference(
                identity: "firebase-ios-sdk",
                repositoryURL: "https://github.com/firebase/firebase-ios-sdk.git",
                requirement: .upToNextMajorVersion("11.0.0")
            )
        ]
    )

    let diagnostics = DependencyHealthDiagnoser().diagnose(projects: [project], resolvedPackages: [])

    #expect(diagnostics.contains { $0.rule == .missingPackageResolved && $0.severity == .error })
}

@Test
func reportsReferencedMissingResolvedAndResolvedMissingReference() {
    let project = ProjectScanResult(
        path: "/tmp/MyApp.xcodeproj",
        packageReferences: [
            PackageReference(
                identity: "firebase-ios-sdk",
                repositoryURL: "https://github.com/firebase/firebase-ios-sdk.git",
                requirement: .upToNextMajorVersion("11.0.0")
            )
        ]
    )
    let resolved = [
        ResolvedPackage(identity: "lottie-spm", location: "https://github.com/airbnb/lottie-spm.git")
    ]

    let rules = DependencyHealthDiagnoser()
        .diagnose(projects: [project], resolvedPackages: resolved)
        .map(\.rule)

    #expect(rules.contains(.packageReferencedButNotResolved))
    #expect(rules.contains(.packageResolvedButNotReferenced))
}

@Test
func reportsRequirementRiskLevelsAndDuplicateURLForms() {
    let project = ProjectScanResult(
        path: "/tmp/MyApp.xcodeproj",
        packageReferences: [
            PackageReference(
                identity: "branchy",
                repositoryURL: "git@github.com:example/Branchy.git",
                requirement: .branch("main")
            ),
            PackageReference(
                identity: "revisioned",
                repositoryURL: "https://github.com/example/Revisioned.git",
                requirement: .revision("abcdef")
            ),
            PackageReference(
                identity: "exact",
                repositoryURL: "https://github.com/example/Exact.git",
                requirement: .exactVersion("1.2.3")
            ),
        ]
    )
    let resolved = [
        ResolvedPackage(identity: "branchy", location: "https://github.com/example/Branchy")
    ]

    let diagnostics = DependencyHealthDiagnoser().diagnose(
        projects: [project],
        resolvedPackages: resolved
    )

    #expect(diagnostics.contains { $0.rule == .branchDependency && $0.severity == .warning })
    #expect(diagnostics.contains { $0.rule == .revisionDependency && $0.severity == .warning })
    #expect(diagnostics.contains { $0.rule == .exactVersionDependency && $0.severity == .info })
    #expect(diagnostics.contains { $0.rule == .duplicateURLForms && $0.severity == .warning })
}
