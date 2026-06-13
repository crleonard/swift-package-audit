import Foundation

public struct PackageVersionCheck: Codable, Equatable, Sendable {
    public var packageIdentity: String
    public var location: String
    public var currentVersion: String
    public var latestVersion: String?
    public var versionsBehind: Int
    public var newerVersions: [String]
    public var requirementKind: String?
    public var requirementValue: String?
    public var latestSatisfiesRequirement: Bool?
    public var requirementNote: String?
    public var majorVersionsBehind: Int
    public var minorVersionsBehind: Int
    public var patchVersionsBehind: Int
    public var error: String?

    public init(
        packageIdentity: String,
        location: String,
        currentVersion: String,
        latestVersion: String? = nil,
        versionsBehind: Int = 0,
        newerVersions: [String] = [],
        requirementKind: String? = nil,
        requirementValue: String? = nil,
        latestSatisfiesRequirement: Bool? = nil,
        requirementNote: String? = nil,
        majorVersionsBehind: Int = 0,
        minorVersionsBehind: Int = 0,
        patchVersionsBehind: Int = 0,
        error: String? = nil
    ) {
        self.packageIdentity = packageIdentity
        self.location = location
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.versionsBehind = versionsBehind
        self.newerVersions = newerVersions
        self.requirementKind = requirementKind
        self.requirementValue = requirementValue
        self.latestSatisfiesRequirement = latestSatisfiesRequirement
        self.requirementNote = requirementNote
        self.majorVersionsBehind = majorVersionsBehind
        self.minorVersionsBehind = minorVersionsBehind
        self.patchVersionsBehind = patchVersionsBehind
        self.error = error
    }
}
