import Foundation
import Testing

@testable import PackageDoctorCore

@Test
func parsesUpToNextMajorReferenceAndProduct() throws {
    let contents = pbxproj(
        packageBlocks: packageReferenceBlock(
            url: "https://github.com/airbnb/lottie-spm.git",
            requirement: """
              kind = upToNextMajorVersion;
              minimumVersion = 4.0.0;
            """
        ) + "\n" + productBlock()
    )

    let parser = XcodeProjectParser()
    let references = parser.parsePackageReferences(in: contents)
    let products = parser.parsePackageProducts(in: contents)

    #expect(references.count == 1)
    #expect(references.first?.identity == "lottie-spm")
    #expect(references.first?.requirement == .upToNextMajorVersion("4.0.0"))
    #expect(products.first?.name == "Lottie")
}

@Test
func parsesBranchRevisionAndExactRequirements() {
    let parser = XcodeProjectParser()
    let contents = pbxproj(
        packageBlocks: [
            packageReferenceBlock(
                id: "AAAAAAAAAAAAAAAAAAAAAAAA",
                url: "https://github.com/example/Branchy.git",
                requirement: """
                  kind = branch;
                  branch = main;
                """
            ),
            packageReferenceBlock(
                id: "BBBBBBBBBBBBBBBBBBBBBBBB",
                url: "https://github.com/example/Revisioned.git",
                requirement: """
                  kind = revision;
                  revision = abcdef;
                """
            ),
            packageReferenceBlock(
                id: "CCCCCCCCCCCCCCCCCCCCCCCC",
                url: "https://github.com/example/Exact.git",
                requirement: """
                  kind = exactVersion;
                  version = 1.2.3;
                """
            ),
        ].joined(separator: "\n")
    )

    let requirements = parser.parsePackageReferences(in: contents).map(\.requirement)

    #expect(requirements.contains(.branch("main")))
    #expect(requirements.contains(.revision("abcdef")))
    #expect(requirements.contains(.exactVersion("1.2.3")))
}
