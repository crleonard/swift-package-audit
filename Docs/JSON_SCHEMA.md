# JSON Output Schema

Swift Package Audit JSON output is versioned with `schemaVersion`.
The current schema version is `1`. Patch releases may add optional fields, but existing fields in schema version 1 should remain stable throughout the 1.x line.

Generate JSON with:

```sh
swift-package-audit scan --format json
```

## Top-Level Object

```json
{
  "schemaVersion": 1,
  "rootPath": "/path/to/repo",
  "projects": [],
  "workspacePaths": [],
  "packageManifestPaths": [],
  "resolvedPackages": [],
  "resolvedFilePaths": [],
  "versionChecks": [],
  "diagnostics": [],
  "suppressedDiagnostics": [],
  "infoMessages": []
}
```

## Diagnostic

Each diagnostic includes a stable `id` suitable for baselines:

```json
{
  "id": "stable-diagnostic-id",
  "rule": "branchDependency",
  "severity": "warning",
  "packageIdentity": "example",
  "projectPath": "/path/to/MyApp.xcodeproj",
  "message": "example is pinned to branch 'main'.",
  "suggestion": "Prefer a versioned release for reproducible builds."
}
```

## Rules

Known rule identifiers:
- `missingPackageResolved`
- `packageReferencedButNotResolved`
- `packageResolvedButNotReferenced`
- `branchDependency`
- `revisionDependency`
- `exactVersionDependency`
- `duplicateURLForms`
- `packageIdentityMismatch`
- `packageManifestNotResolved`
- `parseError`
- `outdatedVersion`

## Severity

Known severities:
- `info`
- `warning`
- `error`

## Baselines

Baselines use the diagnostic `id` values from the schema:

```sh
swift-package-audit scan --write-baseline SwiftPackageAuditBaseline.json
swift-package-audit scan --baseline SwiftPackageAuditBaseline.json
```

Diagnostics matched by the baseline are moved from `diagnostics` to `suppressedDiagnostics`.

## Version Checks
`versionChecks` is populated only when scans run with `--check`.

```json
{
  "packageIdentity": "example",
  "location": "https://github.com/example/example.git",
  "currentVersion": "1.0.0",
  "latestVersion": "1.2.1",
  "versionsBehind": 3,
  "newerVersions": ["1.1.0", "1.2.0", "1.2.1"],
  "majorVersionsBehind": 0,
  "minorVersionsBehind": 2,
  "patchVersionsBehind": 1,
  "requirementKind": "upToNextMajorVersion",
  "requirementValue": "1.0.0",
  "latestSatisfiesRequirement": true,
  "requirementNote": "The existing upToNextMajorVersion requirement allows the latest version."
}
```

When a check fails for a package, `error` is populated and no `outdatedVersion` diagnostic is emitted for that package.
