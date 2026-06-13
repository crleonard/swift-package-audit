import Foundation

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
