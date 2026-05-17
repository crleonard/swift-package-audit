import Foundation

public enum XcodeProjectParserError: Error, CustomStringConvertible, Sendable {
    case missingProjectFile(URL)
    case unreadable(URL, String)

    public var description: String {
        switch self {
        case .missingProjectFile(let url):
            "Could not find project.pbxproj in \(url.path)."
        case .unreadable(let url, let reason):
            "Could not read \(url.path): \(reason)"
        }
    }
}

public struct XcodeProjectParser: Sendable {
    public init() {}

    public func parse(projectURL: URL) throws -> ProjectScanResult {
        let pbxprojURL = projectURL.appendingPathComponent("project.pbxproj")
        guard FileManager.default.fileExists(atPath: pbxprojURL.path) else {
            throw XcodeProjectParserError.missingProjectFile(projectURL)
        }

        let contents: String
        do {
            contents = try String(contentsOf: pbxprojURL, encoding: .utf8)
        } catch {
            throw XcodeProjectParserError.unreadable(pbxprojURL, error.localizedDescription)
        }

        return ProjectScanResult(
            path: projectURL.path,
            packageReferences: parsePackageReferences(in: contents, projectPath: projectURL.path),
            products: parsePackageProducts(in: contents)
        )
    }

    public func parsePackageReferences(in contents: String, projectPath: String? = nil)
        -> [PackageReference]
    {
        objectBlocks(in: contents, isa: "XCRemoteSwiftPackageReference").compactMap { block in
            guard let repositoryURL = value(named: "repositoryURL", in: block) else {
                return nil
            }

            let normalized = PackageURLNormalizer.normalize(repositoryURL)
            return PackageReference(
                identity: normalized.identity,
                repositoryURL: repositoryURL,
                requirement: requirement(in: block),
                projectPath: projectPath
            )
        }
    }

    public func parsePackageProducts(in contents: String) -> [PackageProduct] {
        objectBlocks(in: contents, isa: "XCSwiftPackageProductDependency").compactMap { block in
            guard let productName = value(named: "productName", in: block) else {
                return nil
            }

            return PackageProduct(
                name: productName,
                packageIdentity: value(named: "package", in: block)
            )
        }
    }

    private func objectBlocks(in contents: String, isa: String) -> [String] {
        let pattern = #"(?s)[A-Z0-9]+ /\* .*? \*/ = \{.*?isa = \#(isa);.*?\};"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(contents.startIndex..<contents.endIndex, in: contents)
        return regex.matches(in: contents, range: range).compactMap { match in
            Range(match.range, in: contents).map { String(contents[$0]) }
        }
    }

    private func value(named name: String, in block: String) -> String? {
        let pattern = #"\b\#(name)\s*=\s*("?)([^";]+)\2;"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(block.startIndex..<block.endIndex, in: block)
        guard let match = regex.firstMatch(in: block, range: range),
            let valueRange = Range(match.range(at: 3), in: block)
        else {
            return nil
        }

        return String(block[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func requirement(in block: String) -> PackageRequirement {
        let kind = value(named: "kind", in: block)
        let minimumVersion = value(named: "minimumVersion", in: block)
        let version = value(named: "version", in: block)
        let branch = value(named: "branch", in: block)
        let revision = value(named: "revision", in: block)
        let maximumVersion = value(named: "maximumVersion", in: block)

        switch kind {
        case "upToNextMajorVersion":
            return .upToNextMajorVersion(minimumVersion ?? version ?? "")
        case "upToNextMinorVersion":
            return .upToNextMinorVersion(minimumVersion ?? version ?? "")
        case "exactVersion":
            return .exactVersion(version ?? minimumVersion ?? "")
        case "branch":
            return .branch(branch ?? "")
        case "revision":
            return .revision(revision ?? "")
        case "versionRange":
            return .range(from: minimumVersion, to: maximumVersion)
        default:
            return .unknown(kind)
        }
    }
}
