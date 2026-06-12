import Foundation
import Testing

@testable import SwiftPackageAuditCore

@Test
func parsesModernPackageResolvedFormat() throws {
    let root = try makeTemporaryDirectory()
    let file = root.appendingPathComponent("Package.resolved")
    try write(
        modernResolved(
            resolvedPin(
                identity: "swift-argument-parser",
                location: "https://github.com/apple/swift-argument-parser.git",
                version: "1.8.2",
                revision: "abc123"
            )
        ),
        to: file
    )

    let packages = try PackageResolvedParser().parse(fileURL: file)

    #expect(packages == [
        ResolvedPackage(
            identity: "swift-argument-parser",
            location: "https://github.com/apple/swift-argument-parser.git",
            version: "1.8.2",
            revision: "abc123",
            resolvedFilePath: file.path
        )
    ])
}

@Test
func parsesLegacyPackageResolvedFormat() throws {
    let root = try makeTemporaryDirectory()
    let file = root.appendingPathComponent("Package.resolved")
    try write(
        """
        {
          "object": {
            "pins": [
              {
                "package": "Nimble",
                "repositoryURL": "https://github.com/Quick/Nimble.git",
                "state": {
                  "branch": "main",
                  "revision": "def456"
                }
              }
            ]
          },
          "version": 1
        }
        """,
        to: file
    )

    let packages = try PackageResolvedParser().parse(fileURL: file)

    #expect(packages.first?.identity == "Nimble")
    #expect(packages.first?.location == "https://github.com/Quick/Nimble.git")
    #expect(packages.first?.branch == "main")
}
