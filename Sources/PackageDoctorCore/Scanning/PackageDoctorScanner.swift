import Foundation

public struct PackageDoctorScanner {
    private let fileManager: FileManager
    private let projectParser: XcodeProjectParser
    private let resolvedParser: PackageResolvedParser
    private let diagnoser: DependencyHealthDiagnoser
    private let configLoader: PackageDoctorConfigLoader
    private let baselineStore: DiagnosticBaselineStore
    private let versionChecker: PackageVersionChecking

    public init(
        fileManager: FileManager = .default,
        projectParser: XcodeProjectParser = XcodeProjectParser(),
        resolvedParser: PackageResolvedParser = PackageResolvedParser(),
        diagnoser: DependencyHealthDiagnoser = DependencyHealthDiagnoser(),
        configLoader: PackageDoctorConfigLoader = PackageDoctorConfigLoader(),
        baselineStore: DiagnosticBaselineStore = DiagnosticBaselineStore(),
        versionChecker: PackageVersionChecking = PackageVersionChecker()
    ) {
        self.fileManager = fileManager
        self.projectParser = projectParser
        self.resolvedParser = resolvedParser
        self.diagnoser = diagnoser
        self.configLoader = configLoader
        self.baselineStore = baselineStore
        self.versionChecker = versionChecker
    }

    public func scan(configuration: ScanConfiguration) -> WorkspaceScanResult {
        let rootURL = URL(fileURLWithPath: configuration.path).standardizedFileURL
        var inventory = discover(from: rootURL)
        inventory.projectURLs.append(contentsOf: discoverWorkspaceProjects(workspaceURLs: inventory.workspaceURLs))
        inventory.deduplicate()

        var infoMessages: [String] = []
        let config = loadConfig(configuration: configuration, infoMessages: &infoMessages)
        let baseline = loadBaseline(configuration: configuration, infoMessages: &infoMessages)

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

        for resolvedURL in inventory.resolvedURLs {
            do {
                resolvedPackages.append(contentsOf: try resolvedParser.parse(fileURL: resolvedURL))
            } catch {
                infoMessages.append(String(describing: error))
            }
        }

        let versionChecks = configuration.checkVersions
            ? versionChecker.check(resolvedPackages: resolvedPackages)
            : []

        var rawDiagnostics = diagnoser.diagnose(
            projects: projects,
            resolvedPackages: resolvedPackages,
            packageManifestPaths: inventory.packageManifestURLs.map(\.path)
        )
        rawDiagnostics.append(contentsOf: versionDiagnostics(from: versionChecks))
        let filteredDiagnostics = applyConfig(config, to: rawDiagnostics)
        let (diagnostics, suppressedDiagnostics) = applyBaseline(baseline, to: filteredDiagnostics)

        return WorkspaceScanResult(
            rootPath: rootURL.path,
            projects: projects,
            workspacePaths: inventory.workspaceURLs.map(\.path),
            packageManifestPaths: inventory.packageManifestURLs.map(\.path),
            resolvedPackages: resolvedPackages,
            resolvedFilePaths: inventory.resolvedURLs.map(\.path),
            versionChecks: versionChecks,
            diagnostics: diagnostics,
            suppressedDiagnostics: suppressedDiagnostics,
            infoMessages: infoMessages
        )
    }

    public func resolvedConfigPath(configuration: ScanConfiguration) -> String? {
        if let configPath = configuration.configPath {
            return URL(fileURLWithPath: configPath).standardizedFileURL.path
        }

        let rootURL = URL(fileURLWithPath: configuration.path).standardizedFileURL
        let defaultConfigURL = rootURL.appendingPathComponent("PackageDoctor.yml")
        guard fileManager.fileExists(atPath: defaultConfigURL.path) else {
            return nil
        }
        return defaultConfigURL.path
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

    private func discoverWorkspaceProjects(workspaceURLs: [URL]) -> [URL] {
        workspaceURLs.flatMap { workspaceURL -> [URL] in
            let contentsURL = workspaceURL.appendingPathComponent("contents.xcworkspacedata")
            guard let contents = try? String(contentsOf: contentsURL, encoding: .utf8) else {
                return []
            }

            return workspaceLocations(in: contents).compactMap { location in
                projectURL(location: location, workspaceURL: workspaceURL)
            }
        }
    }

    private func workspaceLocations(in contents: String) -> [String] {
        let pattern = #"location\s*=\s*"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(contents.startIndex..<contents.endIndex, in: contents)
        return regex.matches(in: contents, range: range).compactMap { match in
            Range(match.range(at: 1), in: contents).map { String(contents[$0]) }
        }
    }

    private func projectURL(location: String, workspaceURL: URL) -> URL? {
        let path: String
        if location.hasPrefix("group:") {
            path = String(location.dropFirst("group:".count))
        } else if location.hasPrefix("self:") {
            path = String(location.dropFirst("self:".count))
        } else if location.hasPrefix("absolute:") {
            let absolutePath = String(location.dropFirst("absolute:".count))
            return absolutePath.hasSuffix(".xcodeproj") ? URL(fileURLWithPath: absolutePath) : nil
        } else {
            return nil
        }

        guard path.hasSuffix(".xcodeproj") else {
            return nil
        }

        return workspaceURL.deletingLastPathComponent()
            .appendingPathComponent(path)
            .standardizedFileURL
    }

    private func loadConfig(
        configuration: ScanConfiguration,
        infoMessages: inout [String]
    ) -> PackageDoctorConfig {
        let configPath = resolvedConfigPath(configuration: configuration)
        guard let configPath else {
            return PackageDoctorConfig()
        }

        do {
            return try configLoader.load(path: configPath)
        } catch {
            infoMessages.append(String(describing: error))
            return PackageDoctorConfig()
        }
    }

    private func loadBaseline(
        configuration: ScanConfiguration,
        infoMessages: inout [String]
    ) -> DiagnosticBaseline? {
        guard let baselinePath = configuration.baselinePath else {
            return nil
        }

        do {
            return try baselineStore.load(path: baselinePath)
        } catch {
            infoMessages.append(String(describing: error))
            return nil
        }
    }

    private func applyConfig(
        _ config: PackageDoctorConfig,
        to diagnostics: [Diagnostic]
    ) -> [Diagnostic] {
        diagnostics.filter { diagnostic in
            if config.ignoredRules.contains(diagnostic.rule) {
                return false
            }

            if let packageIdentity = diagnostic.packageIdentity,
                config.ignoredPackages.contains(where: {
                    $0.caseInsensitiveCompare(packageIdentity) == .orderedSame
                }) {
                return false
            }

            if diagnostic.rule == .branchDependency,
                let packageIdentity = diagnostic.packageIdentity,
                config.allowedBranchDependencies.contains(where: {
                    $0.caseInsensitiveCompare(packageIdentity) == .orderedSame
                }) {
                return false
            }

            if diagnostic.rule == .missingPackageResolved && !config.requirePackageResolved {
                return false
            }

            if diagnostic.rule == .exactVersionDependency && config.allowExactVersions {
                return false
            }

            return true
        }
    }

    private func applyBaseline(
        _ baseline: DiagnosticBaseline?,
        to diagnostics: [Diagnostic]
    ) -> (active: [Diagnostic], suppressed: [Diagnostic]) {
        guard let baseline else {
            return (diagnostics, [])
        }

        let baselineIDs = Set(baseline.diagnostics.map(\.id))
        let suppressed = diagnostics.filter { baselineIDs.contains($0.id) }
        let active = diagnostics.filter { !baselineIDs.contains($0.id) }
        return (active, suppressed)
    }

    private func versionDiagnostics(from checks: [PackageVersionCheck]) -> [Diagnostic] {
        checks.compactMap { check in
            guard check.versionsBehind > 0, let latestVersion = check.latestVersion else {
                return nil
            }

            let versions = check.newerVersions.joined(separator: ", ")
            return Diagnostic(
                rule: .outdatedVersion,
                severity: .warning,
                packageIdentity: check.packageIdentity,
                message:
                    """
                    \(check.packageIdentity) is on \(check.currentVersion); latest is \(latestVersion) \
                    (\(check.versionsBehind) release tags behind: \(versions)).
                    """,
                suggestion: "Review the package release notes and update when ready."
            )
        }
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

    mutating func deduplicate() {
        projectURLs = deduplicated(projectURLs)
        workspaceURLs = deduplicated(workspaceURLs)
        packageManifestURLs = deduplicated(packageManifestURLs)
        resolvedURLs = deduplicated(resolvedURLs)
    }

    private func deduplicated(_ urls: [URL]) -> [URL] {
        Array(Dictionary(grouping: urls, by: \.standardizedFileURL.path).compactMap { $0.value.first })
            .sorted { $0.path < $1.path }
    }
}
