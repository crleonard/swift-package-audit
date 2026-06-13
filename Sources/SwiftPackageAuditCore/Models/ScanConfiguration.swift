import Foundation

public struct ScanConfiguration: Codable, Equatable, Sendable {
    public var path: String
    public var strict: Bool
    public var configPath: String?
    public var baselinePath: String?
    public var checkVersions: Bool

    public init(
        path: String = ".",
        strict: Bool = false,
        configPath: String? = nil,
        baselinePath: String? = nil,
        checkVersions: Bool = false
    ) {
        self.path = path
        self.strict = strict
        self.configPath = configPath
        self.baselinePath = baselinePath
        self.checkVersions = checkVersions
    }
}
