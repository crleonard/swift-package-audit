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
func reportsPurePackageSwiftAsInformationalWhenNoDependencyGraphIsResolved() throws {
    let root = try makeTemporaryDirectory()
    try write("// swift-tools-version: 6.0\n", to: root.appendingPathComponent("Package.swift"))

    let result = PackageDoctorScanner().scan(configuration: ScanConfiguration(path: root.path))

    #expect(result.packageManifestPaths.count == 1)
    #expect(result.diagnostics.contains { $0.rule == .packageManifestNotResolved })
}
