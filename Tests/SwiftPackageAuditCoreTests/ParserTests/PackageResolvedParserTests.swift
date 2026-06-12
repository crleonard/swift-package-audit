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

@Test
func fallsBackToURLIdentityWhenPackageResolvedPinHasNoIdentity() throws {
    let root = try makeTemporaryDirectory()
    let file = root.appendingPathComponent("Package.resolved")
    try write(
        """
        {
          "pins": [
            {
              "kind": "remoteSourceControl",
              "location": "https://github.com/Point-Freeco/swift-snapshot-testing.git",
              "state": {
                "revision": "abc123",
                "version": "1.0.0"
              }
            }
          ],
          "version": 3
        }
        """,
        to: file
    )

    let packages = try PackageResolvedParser().parse(fileURL: file)

    #expect(packages.first?.identity == "swift-snapshot-testing")
    #expect(packages.first?.resolvedFilePath == file.path)
}

@Test
func packageResolvedParserReportsUnreadableInvalidAndUnsupportedFiles() throws {
    let root = try makeTemporaryDirectory()
    let missingFile = root.appendingPathComponent("missing.resolved")
    do {
        _ = try PackageResolvedParser().parse(fileURL: missingFile)
        #expect(Bool(false))
    } catch PackageResolvedParserError.unreadable(let url, let reason) {
        #expect(url == missingFile)
        #expect(!reason.isEmpty)
    }

    let invalidFile = root.appendingPathComponent("invalid.resolved")
    try write("{", to: invalidFile)
    do {
        _ = try PackageResolvedParser().parse(fileURL: invalidFile)
        #expect(Bool(false))
    } catch PackageResolvedParserError.invalidJSON(let url, let reason) {
        #expect(url == invalidFile)
        #expect(!reason.isEmpty)
    }

    let unsupportedFile = root.appendingPathComponent("unsupported.resolved")
    try write("{}", to: unsupportedFile)
    do {
        _ = try PackageResolvedParser().parse(fileURL: unsupportedFile)
        #expect(Bool(false))
    } catch PackageResolvedParserError.unsupportedSchema(let url) {
        #expect(url == unsupportedFile)
    }
}
