import Foundation

public struct ProjectScanResult: Codable, Equatable, Sendable {
    public var path: String
    public var packageReferences: [PackageReference]
    public var products: [PackageProduct]
    public var parseErrors: [String]

    public init(
        path: String,
        packageReferences: [PackageReference] = [],
        products: [PackageProduct] = [],
        parseErrors: [String] = []
    ) {
        self.path = path
        self.packageReferences = packageReferences
        self.products = products
        self.parseErrors = parseErrors
    }
}
