import Foundation

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
