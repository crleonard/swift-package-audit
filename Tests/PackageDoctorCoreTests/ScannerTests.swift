import Foundation
import Testing

@testable import PackageDoctorCore

@Test
func scansWorkspaceWithMultipleProjects() throws {
    let root = try makeTemporaryDirectory()
    try FileManager.default.createDirectory(
        at: root.appendingPathComponent("Apps.xcworkspace"),
        withIntermediateDirectories: true
    )

    let appProject = root.appendingPathComponent("App/MyApp.xcodeproj")
    let toolsProject = root.appendingPathComponent("Tools/Tools.xcodeproj")
    try write(
        pbxproj(
            packageBlocks: packageReferenceBlock(
                url: "https://github.com/airbnb/lottie-spm.git",
                requirement: """
                  kind = upToNextMajorVersion;
                  minimumVersion = 4.0.0;
                """
            )
        ),
        to: appProject.appendingPathComponent("project.pbxproj")
    )
    try write(
        pbxproj(
            packageBlocks: packageReferenceBlock(
                url: "https://github.com/Quick/Nimble.git",
                requirement: """
                  kind = branch;
                  branch = main;
                """
            )
        ),
        to: toolsProject.appendingPathComponent("project.pbxproj")
    )
    try write(
        modernResolved(
            [
                resolvedPin(
                    identity: "lottie-spm",
                    location: "https://github.com/airbnb/lottie-spm.git"
                ),
                resolvedPin(
                    identity: "nimble",
                    location: "https://github.com/Quick/Nimble.git",
                    branch: "main"
                ),
            ].joined(separator: ",\n")
        ),
        to: root.appendingPathComponent("Package.resolved")
    )

    let result = PackageDoctorScanner().scan(configuration: ScanConfiguration(path: root.path))

    #expect(result.workspacePaths.count == 1)
    #expect(result.projects.count == 2)
    #expect(result.projects.flatMap(\.packageReferences).count == 2)
    #expect(result.diagnostics.contains { $0.rule == .branchDependency })
}

@Test
func scansProjectsReferencedByWorkspaceXML() throws {
    let root = try makeTemporaryDirectory()
    let workspace = root.appendingPathComponent("Container/App.xcworkspace")
    try write(
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <Workspace version="1.0">
          <FileRef location="group:../Projects/MyApp.xcodeproj"></FileRef>
        </Workspace>
        """,
        to: workspace.appendingPathComponent("contents.xcworkspacedata")
    )

    let project = root.appendingPathComponent("Projects/MyApp.xcodeproj")
    try write(
        pbxproj(
            packageBlocks: packageReferenceBlock(
                url: "https://github.com/apple/swift-argument-parser.git",
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
                identity: "swift-argument-parser",
                location: "https://github.com/apple/swift-argument-parser.git"
            )
        ),
        to: root.appendingPathComponent("Package.resolved")
    )

    let result = PackageDoctorScanner().scan(configuration: ScanConfiguration(path: root.path))

    #expect(result.projects.map { URL(fileURLWithPath: $0.path).lastPathComponent } == ["MyApp.xcodeproj"])
    #expect(result.projects.flatMap(\.packageReferences).count == 1)
}

@Test
func scansPackageResolvedInsideXcodeProjectBundle() throws {
    let root = try makeTemporaryDirectory()
    let project = root.appendingPathComponent("MyApp.xcodeproj")
    try write(
        pbxproj(
            packageBlocks: packageReferenceBlock(
                url: "https://github.com/apple/swift-argument-parser.git",
                requirement: """
                  kind = upToNextMajorVersion;
                  minimumVersion = 1.0.0;
                """
            )
        ),
        to: project.appendingPathComponent("project.pbxproj")
    )
    let nestedResolved = project
        .appendingPathComponent("project.xcworkspace")
        .appendingPathComponent("xcshareddata")
        .appendingPathComponent("swiftpm")
        .appendingPathComponent("Package.resolved")
    try write(
        modernResolved(
            resolvedPin(
                identity: "swift-argument-parser",
                location: "https://github.com/apple/swift-argument-parser.git"
            )
        ),
        to: nestedResolved
    )

    let result = PackageDoctorScanner().scan(configuration: ScanConfiguration(path: root.path))

    #expect(result.projects.map { URL(fileURLWithPath: $0.path).lastPathComponent } == ["MyApp.xcodeproj"])
    #expect(result.resolvedFilePaths.count == 1)
    #expect(
        result.resolvedFilePaths[0]
            .hasSuffix("MyApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved")
    )
    #expect(result.resolvedPackages.map(\.identity) == ["swift-argument-parser"])
    #expect(!result.diagnostics.contains { $0.rule == .missingPackageResolved })
    #expect(!result.diagnostics.contains { $0.rule == .packageReferencedButNotResolved })
}

@Test
func reportsPurePackageSwiftAsInformationalWhenNoDependencyGraphIsResolved() throws {
    let root = try makeTemporaryDirectory()
    try write("// swift-tools-version: 6.0\n", to: root.appendingPathComponent("Package.swift"))

    let result = PackageDoctorScanner().scan(configuration: ScanConfiguration(path: root.path))

    #expect(result.packageManifestPaths.count == 1)
    #expect(result.diagnostics.contains { $0.rule == .packageManifestNotResolved })
}
