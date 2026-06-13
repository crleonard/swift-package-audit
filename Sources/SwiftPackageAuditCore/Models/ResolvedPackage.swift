import Foundation

public struct ResolvedPackage: Codable, Equatable, Sendable {
    public var identity: String
    public var location: String
    public var version: String?
    public var revision: String?
    public var branch: String?
    public var resolvedFilePath: String?

    public init(
        identity: String,
        location: String,
        version: String? = nil,
        revision: String? = nil,
        branch: String? = nil,
        resolvedFilePath: String? = nil
    ) {
        self.identity = identity
        self.location = location
        self.version = version
        self.revision = revision
        self.branch = branch
        self.resolvedFilePath = resolvedFilePath
    }
}
