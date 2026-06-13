import Foundation

public struct PackageReference: Codable, Equatable, Sendable {
    public var identity: String
    public var repositoryURL: String
    public var requirement: PackageRequirement
    public var products: [PackageProduct]
    public var projectPath: String?

    public init(
        identity: String,
        repositoryURL: String,
        requirement: PackageRequirement,
        products: [PackageProduct] = [],
        projectPath: String? = nil
    ) {
        self.identity = identity
        self.repositoryURL = repositoryURL
        self.requirement = requirement
        self.products = products
        self.projectPath = projectPath
    }
}
