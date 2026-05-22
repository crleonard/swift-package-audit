import Foundation

public struct DependencyHealthDiagnoser: Sendable {
    public init() {}

    public func diagnose(
        projects: [ProjectScanResult],
        resolvedPackages: [ResolvedPackage],
        packageManifestPaths: [String] = []
    ) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []
        let references = projects.flatMap(\.packageReferences)

        diagnostics.append(contentsOf: parseErrorDiagnostics(for: projects))
        diagnostics.append(contentsOf: missingResolvedDiagnostics(projects, resolvedPackages))
        diagnostics.append(contentsOf: unresolvedReferenceDiagnostics(references, resolvedPackages))
        diagnostics.append(contentsOf: staleResolvedDiagnostics(references, resolvedPackages))
        diagnostics.append(contentsOf: requirementDiagnostics(references))
        diagnostics.append(contentsOf: duplicateURLDiagnostics(references, resolvedPackages))
        diagnostics.append(contentsOf: identityMismatchDiagnostics(references, resolvedPackages))

        if projects.isEmpty && resolvedPackages.isEmpty && !packageManifestPaths.isEmpty {
            diagnostics.append(
                Diagnostic(
                    rule: .packageManifestNotResolved,
                    severity: .info,
                    message:
                        "Package.swift was found, but dependency information was not resolved during this read-only scan.",
                    suggestion:
                        "Run swift package show-dependencies --format json separately if you need pure SwiftPM dependency details."
                )
            )
        }

        return diagnostics.sorted { lhs, rhs in
            if lhs.severity != rhs.severity {
                return lhs.severity > rhs.severity
            }
            return lhs.message < rhs.message
        }
    }

    private func parseErrorDiagnostics(for projects: [ProjectScanResult]) -> [Diagnostic] {
        projects.flatMap { project in
            project.parseErrors.map { error in
                Diagnostic(
                    rule: .parseError,
                    severity: .warning,
                    projectPath: project.path,
                    message: error
                )
            }
        }
    }

    private func missingResolvedDiagnostics(
        _ projects: [ProjectScanResult],
        _ resolvedPackages: [ResolvedPackage]
    ) -> [Diagnostic] {
        guard resolvedPackages.isEmpty else {
            return []
        }

        return projects.filter { !$0.packageReferences.isEmpty }.map { project in
            Diagnostic(
                rule: .missingPackageResolved,
                severity: .error,
                projectPath: project.path,
                message:
                    "Xcode project contains Swift package references, but no Package.resolved file was found.",
                suggestion:
                    "Run xcodebuild -resolvePackageDependencies and commit the generated Package.resolved file."
            )
        }
    }

    private func unresolvedReferenceDiagnostics(
        _ references: [PackageReference],
        _ resolvedPackages: [ResolvedPackage]
    ) -> [Diagnostic] {
        guard !resolvedPackages.isEmpty else {
            return []
        }

        let resolvedKeys = Set(resolvedPackages.flatMap(keys(for:)))
        return references.filter { reference in
            keys(for: reference).isDisjoint(with: resolvedKeys)
        }.map { reference in
            Diagnostic(
                rule: .packageReferencedButNotResolved,
                severity: .error,
                packageIdentity: reference.identity,
                projectPath: reference.projectPath,
                message:
                    "\(reference.identity) is referenced by the Xcode project, but it is missing from Package.resolved.",
                suggestion: "Run xcodebuild -resolvePackageDependencies."
            )
        }
    }

    private func staleResolvedDiagnostics(
        _ references: [PackageReference],
        _ resolvedPackages: [ResolvedPackage]
    ) -> [Diagnostic] {
        guard !references.isEmpty else {
            return []
        }

        let referenceKeys = Set(references.flatMap(keys(for:)))
        return resolvedPackages.filter { resolved in
            keys(for: resolved).isDisjoint(with: referenceKeys)
        }.map { resolved in
            Diagnostic(
                rule: .packageResolvedButNotReferenced,
                severity: .warning,
                packageIdentity: resolved.identity,
                message:
                    "\(resolved.identity) is present in Package.resolved, but it is not referenced by the Xcode project.",
                suggestion: "Remove stale resolved pins or re-resolve dependencies."
            )
        }
    }

    private func requirementDiagnostics(_ references: [PackageReference]) -> [Diagnostic] {
        references.compactMap { reference in
            switch reference.requirement {
            case .branch(let branch):
                Diagnostic(
                    rule: .branchDependency,
                    severity: .warning,
                    packageIdentity: reference.identity,
                    projectPath: reference.projectPath,
                    message: "\(reference.identity) is pinned to branch '\(branch)'.",
                    suggestion: "Prefer a versioned release for reproducible builds."
                )
            case .revision:
                Diagnostic(
                    rule: .revisionDependency,
                    severity: .warning,
                    packageIdentity: reference.identity,
                    projectPath: reference.projectPath,
                    message: "\(reference.identity) is pinned to a raw revision.",
                    suggestion: "Use a tagged version where possible."
                )
            case .exactVersion(let version):
                Diagnostic(
                    rule: .exactVersionDependency,
                    severity: .info,
                    packageIdentity: reference.identity,
                    projectPath: reference.projectPath,
                    message: "\(reference.identity) is pinned to exact version \(version).",
                    suggestion: "This may be intentional, but it can block patch updates."
                )
            default:
                nil
            }
        }
    }

    private func duplicateURLDiagnostics(
        _ references: [PackageReference],
        _ resolvedPackages: [ResolvedPackage]
    ) -> [Diagnostic] {
        let urls = references.map(\.repositoryURL) + resolvedPackages.map(\.location)
        let grouped = Dictionary(grouping: urls) { PackageURLNormalizer.normalize($0).normalizedURL }
        return grouped.compactMap { normalized, originals in
            let uniqueOriginals = Array(Set(originals))
            guard uniqueOriginals.count > 1 else {
                return nil
            }

            return Diagnostic(
                rule: .duplicateURLForms,
                severity: .warning,
                packageIdentity: PackageURLNormalizer.normalize(normalized).identity,
                message:
                    "Package appears with multiple URL forms: \(uniqueOriginals.sorted().joined(separator: ", ")).",
                suggestion: "Normalize package URLs to reduce duplicate identities and merge noise."
            )
        }
    }

    private func identityMismatchDiagnostics(
        _ references: [PackageReference],
        _ resolvedPackages: [ResolvedPackage]
    ) -> [Diagnostic] {
        let resolvedByURL = Dictionary(grouping: resolvedPackages) {
            PackageURLNormalizer.normalize($0.location).normalizedURL
        }

        return references.compactMap { reference in
            let normalizedURL = PackageURLNormalizer.normalize(reference.repositoryURL)
            guard let resolved = resolvedByURL[normalizedURL.normalizedURL]?.first else {
                return nil
            }

            let resolvedIdentity = resolved.identity.lowercased()
            guard reference.identity.lowercased() != resolvedIdentity else {
                return nil
            }

            return Diagnostic(
                rule: .packageIdentityMismatch,
                severity: .warning,
                packageIdentity: reference.identity,
                projectPath: reference.projectPath,
                message:
                    "Package identity '\(reference.identity)' differs from resolved identity '\(resolved.identity)'.",
                suggestion: "Check whether the package URL changed or was renamed."
            )
        }
    }

    private func keys(for reference: PackageReference) -> Set<String> {
        [
            "identity:\(reference.identity.lowercased())",
            "url:\(PackageURLNormalizer.normalize(reference.repositoryURL).normalizedURL)",
        ]
    }

    private func keys(for resolved: ResolvedPackage) -> Set<String> {
        [
            "identity:\(resolved.identity.lowercased())",
            "url:\(PackageURLNormalizer.normalize(resolved.location).normalizedURL)",
        ]
    }
}
