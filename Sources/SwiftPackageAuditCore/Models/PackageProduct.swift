import Foundation

public struct PackageProduct: Codable, Equatable, Sendable {
    public var name: String
    public var packageIdentity: String?

    public init(name: String, packageIdentity: String? = nil) {
        self.name = name
        self.packageIdentity = packageIdentity
    }
}
