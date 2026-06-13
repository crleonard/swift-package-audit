import Foundation

public enum PackageRequirement: Codable, Equatable, Sendable {
    case upToNextMajorVersion(String)
    case upToNextMinorVersion(String)
    case exactVersion(String)
    case branch(String)
    case revision(String)
    case range(from: String?, upperBound: String?)
    case unknown(String?)

    public var kind: String {
        switch self {
        case .upToNextMajorVersion: "upToNextMajorVersion"
        case .upToNextMinorVersion: "upToNextMinorVersion"
        case .exactVersion: "exactVersion"
        case .branch: "branch"
        case .revision: "revision"
        case .range: "range"
        case .unknown: "unknown"
        }
    }

    public var displayValue: String? {
        switch self {
        case .upToNextMajorVersion(let value),
            .upToNextMinorVersion(let value),
            .exactVersion(let value),
            .branch(let value),
            .revision(let value):
            value
        case .range(let from, let upperBound):
            [from, upperBound].compactMap(\.self).joined(separator: "..<")
        case .unknown(let value):
            value
        }
    }
}
