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

public struct PackageProduct: Codable, Equatable, Sendable {
    public var name: String
    public var packageIdentity: String?

    public init(name: String, packageIdentity: String? = nil) {
        self.name = name
        self.packageIdentity = packageIdentity
    }
}

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

public struct WorkspaceScanResult: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var rootPath: String
    public var projects: [ProjectScanResult]
    public var workspacePaths: [String]
    public var packageManifestPaths: [String]
    public var resolvedPackages: [ResolvedPackage]
    public var resolvedFilePaths: [String]
    public var versionChecks: [PackageVersionCheck]
    public var diagnostics: [Diagnostic]
    public var suppressedDiagnostics: [Diagnostic]
    public var infoMessages: [String]

    public init(
        schemaVersion: Int = 1,
        rootPath: String,
        projects: [ProjectScanResult] = [],
        workspacePaths: [String] = [],
        packageManifestPaths: [String] = [],
        resolvedPackages: [ResolvedPackage] = [],
        resolvedFilePaths: [String] = [],
        versionChecks: [PackageVersionCheck] = [],
        diagnostics: [Diagnostic] = [],
        suppressedDiagnostics: [Diagnostic] = [],
        infoMessages: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.rootPath = rootPath
        self.projects = projects
        self.workspacePaths = workspacePaths
        self.packageManifestPaths = packageManifestPaths
        self.resolvedPackages = resolvedPackages
        self.resolvedFilePaths = resolvedFilePaths
        self.versionChecks = versionChecks
        self.diagnostics = diagnostics
        self.suppressedDiagnostics = suppressedDiagnostics
        self.infoMessages = infoMessages
    }
}

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

public struct Diagnostic: Codable, Equatable, Sendable {
    public var id: String
    public var rule: DiagnosticRule
    public var severity: DiagnosticSeverity
    public var packageIdentity: String?
    public var projectPath: String?
    public var message: String
    public var suggestion: String?

    public init(
        rule: DiagnosticRule,
        severity: DiagnosticSeverity,
        packageIdentity: String? = nil,
        projectPath: String? = nil,
        message: String,
        suggestion: String? = nil
    ) {
        self.id = Diagnostic.makeID(
            rule: rule,
            packageIdentity: packageIdentity,
            projectPath: projectPath,
            message: message
        )
        self.rule = rule
        self.severity = severity
        self.packageIdentity = packageIdentity
        self.projectPath = projectPath
        self.message = message
        self.suggestion = suggestion
    }

    public static func makeID(
        rule: DiagnosticRule,
        packageIdentity: String?,
        projectPath: String?,
        message: String
    ) -> String {
        [
            rule.rawValue,
            packageIdentity?.lowercased() ?? "",
            URL(fileURLWithPath: projectPath ?? "").lastPathComponent.lowercased(),
            message.normalizedDiagnosticText,
        ].joined(separator: "|").stablePackageDoctorHash
    }
}

public enum DiagnosticSeverity: String, Codable, Comparable, Sendable {
    case info
    case warning
    case error

    public static func < (lhs: DiagnosticSeverity, rhs: DiagnosticSeverity) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .info: 0
        case .warning: 1
        case .error: 2
        }
    }
}

public enum DiagnosticRule: String, Codable, Sendable {
    case missingPackageResolved
    case packageReferencedButNotResolved
    case packageResolvedButNotReferenced
    case branchDependency
    case revisionDependency
    case exactVersionDependency
    case duplicateURLForms
    case packageIdentityMismatch
    case packageManifestNotResolved
    case parseError
    case outdatedVersion
}

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

public enum OutputFormat: String, CaseIterable, Codable, Sendable {
    case text
    case json
    case markdown
    case prComment = "pr-comment"
}
