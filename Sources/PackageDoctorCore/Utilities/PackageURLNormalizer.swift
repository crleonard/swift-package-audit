import Foundation

public struct NormalizedPackageURL: Equatable, Hashable, Sendable {
    public var original: String
    public var normalizedURL: String
    public var identity: String
}

public enum PackageURLNormalizer {
    public static func normalize(_ rawURL: String) -> NormalizedPackageURL {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let httpsURL = convertGitHubSSHToHTTPS(trimmed)
        var normalized = httpsURL

        if var components = URLComponents(string: httpsURL) {
            components.scheme = components.scheme?.lowercased()
            components.host = components.host?.lowercased()
            components.path = stripTrailingGit(from: components.path)
            normalized = components.string ?? httpsURL
        } else {
            normalized = stripTrailingGit(from: httpsURL)
        }

        normalized = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let identity = normalized
            .split(separator: "/")
            .last
            .map { String($0).lowercased() } ?? normalized.lowercased()

        return NormalizedPackageURL(
            original: rawURL,
            normalizedURL: normalized.lowercased(),
            identity: identity
        )
    }

    private static func convertGitHubSSHToHTTPS(_ value: String) -> String {
        guard value.lowercased().hasPrefix("git@github.com:") else {
            return value
        }

        let path = value.dropFirst("git@github.com:".count)
        return "https://github.com/\(path)"
    }

    private static func stripTrailingGit(from value: String) -> String {
        value.hasSuffix(".git") ? String(value.dropLast(4)) : value
    }
}
