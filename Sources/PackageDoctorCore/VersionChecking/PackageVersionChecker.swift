import Foundation

public protocol PackageVersionChecking {
    func check(resolvedPackages: [ResolvedPackage]) -> [PackageVersionCheck]
}

public protocol GitTagProviding {
    func tags(for repositoryURL: String) throws -> [String]
}

public struct PackageVersionChecker: PackageVersionChecking {
    private let tagProvider: GitTagProviding

    public init(tagProvider: GitTagProviding = GitRemoteTagProvider()) {
        self.tagProvider = tagProvider
    }

    public func check(resolvedPackages: [ResolvedPackage]) -> [PackageVersionCheck] {
        resolvedPackages.compactMap { package in
            guard let version = package.version, let current = SemanticVersion(version) else {
                return nil
            }

            do {
                let versions = try tagProvider.tags(for: package.location)
                    .compactMap(SemanticVersion.init(tag:))
                    .uniqued()
                    .sorted()
                let newerVersions = versions.filter { $0 > current }
                return PackageVersionCheck(
                    packageIdentity: package.identity,
                    location: package.location,
                    currentVersion: version,
                    latestVersion: newerVersions.last?.description,
                    versionsBehind: newerVersions.count,
                    newerVersions: newerVersions.map(\.description)
                )
            } catch {
                return PackageVersionCheck(
                    packageIdentity: package.identity,
                    location: package.location,
                    currentVersion: version,
                    error: error.localizedDescription
                )
            }
        }
    }
}

public struct GitRemoteTagProvider: GitTagProviding {
    public init() {}

    public func tags(for repositoryURL: String) throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "ls-remote", "--tags", "--refs", repositoryURL]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw VersionCheckError.gitFailed(error.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return output.components(separatedBy: .newlines).compactMap { line in
            line.components(separatedBy: "refs/tags/").last
        }
    }
}

public enum VersionCheckError: Error, LocalizedError {
    case gitFailed(String)

    public var errorDescription: String? {
        switch self {
        case .gitFailed(let message):
            message.isEmpty ? "git ls-remote failed" : message
        }
    }
}

public struct SemanticVersion: Comparable, CustomStringConvertible, Hashable {
    public var major: Int
    public var minor: Int
    public var patch: Int

    public init?(_ value: String) {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("v")
        guard !cleaned.contains("-") else {
            return nil
        }

        let parts = cleaned.split(separator: ".").map(String.init)
        guard parts.count >= 2,
            let major = Int(parts[0]),
            let minor = Int(parts[1])
        else {
            return nil
        }

        self.major = major
        self.minor = minor
        self.patch = parts.count >= 3 ? Int(parts[2]) ?? 0 : 0
    }

    public init?(tag: String) {
        self.init(tag)
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }
}

private extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
