import Foundation

public struct PackageDoctorScanner {
    private let fileManager: FileManager
    private let projectParser: XcodeProjectParser
    private let resolvedParser: PackageResolvedParser
    private let diagnoser: DependencyHealthDiagnoser

    public init(
        fileManager: FileManager = .default,
        projectParser: XcodeProjectParser = XcodeProjectParser(),
        resolvedParser: PackageResolvedParser = PackageResolvedParser(),
        diagnoser: DependencyHealthDiagnoser = DependencyHealthDiagnoser()
    ) {
        self.fileManager = fileManager
        self.projectParser = projectParser
        self.resolvedParser = resolvedParser
        self.diagnoser = diagnoser
    }

    public func scan(configuration: ScanConfiguration) -> WorkspaceScanResult {
        let rootURL = URL(fileURLWithPath: configuration.path).standardizedFileURL
        let inventory = discover(from: rootURL)

        var projects: [ProjectScanResult] = inventory.projectURLs.map { projectURL in
            do {
                return try projectParser.parse(projectURL: projectURL)
            } catch {
                return ProjectScanResult(
                    path: projectURL.path,
                    parseErrors: [String(describing: error)]
                )
            }
        }

        for projectIndex in projects.indices {
            for referenceIndex in projects[projectIndex].packageReferences.indices {
                projects[projectIndex].packageReferences[referenceIndex].projectPath =
                    projects[projectIndex].path
            }
        }

        var resolvedPackages: [ResolvedPackage] = []
        var infoMessages: [String] = []

        for resolvedURL in inventory.resolvedURLs {
            do {
                resolvedPackages.append(contentsOf: try resolvedParser.parse(fileURL: resolvedURL))
            } catch {
                infoMessages.append(String(describing: error))
            }
        }

        let diagnostics = diagnoser.diagnose(
            projects: projects,
            resolvedPackages: resolvedPackages,
            packageManifestPaths: inventory.packageManifestURLs.map(\.path)
        )

        return WorkspaceScanResult(
            rootPath: rootURL.path,
            projects: projects,
            workspacePaths: inventory.workspaceURLs.map(\.path),
            packageManifestPaths: inventory.packageManifestURLs.map(\.path),
            resolvedPackages: resolvedPackages,
            resolvedFilePaths: inventory.resolvedURLs.map(\.path),
            diagnostics: diagnostics,
            infoMessages: infoMessages
        )
    }

    private func discover(from rootURL: URL) -> Inventory {
        var inventory = Inventory()
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return inventory
        }

        for case let url as URL in enumerator {
            if shouldSkip(url) {
                enumerator.skipDescendants()
                continue
            }

            switch url.lastPathComponent {
            case let name where name.hasSuffix(".xcodeproj"):
                inventory.projectURLs.append(url)
                enumerator.skipDescendants()
            case let name where name.hasSuffix(".xcworkspace"):
                inventory.workspaceURLs.append(url)
            case "Package.swift":
                inventory.packageManifestURLs.append(url)
            case "Package.resolved":
                inventory.resolvedURLs.append(url)
            default:
                continue
            }
        }

        inventory.projectURLs.sort { $0.path < $1.path }
        inventory.workspaceURLs.sort { $0.path < $1.path }
        inventory.packageManifestURLs.sort { $0.path < $1.path }
        inventory.resolvedURLs.sort { $0.path < $1.path }
        return inventory
    }

    private func shouldSkip(_ url: URL) -> Bool {
        let skipped = [".build", "DerivedData", ".git"]
        return skipped.contains(url.lastPathComponent)
    }
}

private struct Inventory {
    var projectURLs: [URL] = []
    var workspaceURLs: [URL] = []
    var packageManifestURLs: [URL] = []
    var resolvedURLs: [URL] = []
}
