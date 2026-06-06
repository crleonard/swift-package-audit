# JSON Output Schema

PackageDoctor JSON output is versioned with `schemaVersion`.

The current schema version is `1`. Patch releases may add optional fields, but existing fields in schema version 1 should remain stable throughout the 1.x line.

Generate JSON with:

```sh
packagedoctor scan --format json
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

## Severity

Known severities:

- `info`
- `warning`
- `error`

## Baselines

Baselines use the diagnostic `id` values from the schema:

```sh
packagedoctor scan --write-baseline PackageDoctorBaseline.json
packagedoctor scan --baseline PackageDoctorBaseline.json
```

Diagnostics matched by the baseline are moved from `diagnostics` to `suppressedDiagnostics`.
