# Swift Package Audit

[![CI](https://github.com/crleonard/swift-package-audit/actions/workflows/ci.yml/badge.svg)](https://github.com/crleonard/swift-package-audit/actions/workflows/ci.yml)
![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange.svg)
![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)

A SwiftPM health checker for real Xcode projects.
Swift Package Audit diagnoses dependency health issues in Xcode SwiftPM setups by comparing what your project asks for against what Package.resolved actually pins.
Status: stable v1.0.0. Swift Package Audit is read-only, does not update packages, and does not edit `project.pbxproj` files.

## Why Swift Package Audit Exists

Many iOS and macOS teams do not manage dependencies through `Package.swift` alone. Real Xcode projects often include:
- `.xcodeproj/project.pbxproj`
- `.xcworkspace`
- `Package.resolved` files inside project or workspace folders
- SwiftPM dependencies configured in Xcode
- UIKit, SwiftUI, and mixed UIKit/SwiftUI apps
- multiple projects in one workspace

Swift Package Audit is dependency tooling, not UI tooling. It works from project metadata and resolved pins, regardless of whether the app uses UIKit, SwiftUI, or both.

## What It Checks Today

The current MVP scans for:
- Xcode projects, workspaces, `Package.swift`, and `Package.resolved`
- Xcode Swift package references in `project.pbxproj`
- modern and legacy `Package.resolved` pin formats
- missing `Package.resolved`
- project references missing from resolved pins
- stale resolved pins that are no longer referenced by the project
- branch-based dependencies
- revision-based dependencies
- exact-version dependencies
- duplicate package URL forms
- suspicious identity mismatches
- config-based rule and package ignores
- diagnostic baselines for existing known issues
- GitHub PR comment output
- optional remote tag checks for newer package versions

Swift Package Audit intentionally avoids network calls during normal scans. Remote version checks only run when you pass `--check`.

## Installation
### Homebrew

```sh
brew tap crleonard/tap
brew install swift-package-audit
```

### Mint
Mint installs directly from a GitHub tag:

```sh
mint install crleonard/swift-package-audit@1.0.0
```

### From Source

```sh
git clone https://github.com/crleonard/swift-package-audit.git
cd swift-package-audit
swift build -c release
```

Run the built executable:

```sh
.build/release/swift-package-audit scan --path /path/to/project
```

## Usage

```sh
swift-package-audit scan
swift-package-audit scan --path .
swift-package-audit scan --format text
swift-package-audit scan --format json
swift-package-audit scan --format markdown
swift-package-audit scan --format pr-comment
swift-package-audit scan --fail-on error
swift-package-audit scan --fail-on warning
swift-package-audit scan --strict
swift-package-audit scan --check
swift-package-audit scan --config SwiftPackageAudit.yml
swift-package-audit scan --baseline SwiftPackageAuditBaseline.json
swift-package-audit scan --write-baseline SwiftPackageAuditBaseline.json
```

`--strict` is equivalent to `--fail-on warning`.

## Examples

### Basic Scan
Swift Package Audit scans Xcode project metadata and resolved pins without modifying project files.

```sh
swift-package-audit scan --path /Users/chrisleonard/Desktop/TESTPROJ
```

```text
Swift Package Audit

Path:
  /Users/chrisleonard/Desktop/TESTPROJ

Projects:
  SwiftPackageAuditPlayground.xcodeproj

Swift packages:
  7 referenced
  8 resolved

Health:
  1 info
  4 warnings
  0 errors
  0 suppressed

Warnings:
  ! nimble
     Package appears with multiple URL forms: git@github.com:Quick/Nimble.git, https://github.com/Quick/Nimble.git.
     Suggestion: Normalize package URLs to reduce duplicate identities and merge noise.
  ! lottie-spm
     lottie-spm is pinned to branch 'main'.
     Suggestion: Prefer a versioned release for reproducible builds.
  ! snapkit
     snapkit is pinned to a raw revision.
     Suggestion: Use a tagged version where possible.
  ! swift-collections
     swift-collections is present in Package.resolved, but it is not referenced by the Xcode project.
     Suggestion: Remove stale resolved pins or re-resolve dependencies.

Info:
  i alamofire
     alamofire is pinned to exact version 5.4.0.
     Suggestion: This may be intentional, but it can block patch updates.
```

Markdown output is designed for general reports. `pr-comment` output is designed for GitHub pull request comments. JSON output is pretty-printed with sorted keys and uses schema version `1`; see [Docs/JSON_SCHEMA.md](Docs/JSON_SCHEMA.md).

### CI Gating
Use `--fail-on`, `--strict`, or `failOn` config rules to make dependency health part of CI.

```yaml
failOn:
  - branchDependency
  - revisionDependency
  - outdatedVersion

rules:
  requirePackageResolved: true
  allowExactVersions: false
```

With that config, the sample scan reports findings and exits non-zero because branch and revision dependencies are present:

```text
Health:
  1 info
  4 warnings
  0 errors
  0 suppressed

EXIT_CODE=1
```

Without a fail policy, the same findings are reported and the command exits successfully:

```text
EXIT_CODE=0
```

### Pull Request Comments

Use `--format pr-comment` to generate GitHub-ready Markdown.

```sh
swift-package-audit scan --format pr-comment --fail-on error
```

```markdown
## Swift Package Audit

| Errors | Warnings | Info | Suppressed |
| ---: | ---: | ---: | ---: |
| 0 | 4 | 1 | 0 |

<details open>
<summary>Dependency health findings</summary>

| Severity | Rule | Package | Message | Suggestion |
| --- | --- | --- | --- | --- |
| warning | branchDependency | lottie-spm | lottie-spm is pinned to branch 'main'. | Prefer a versioned release for reproducible builds. |
| warning | revisionDependency | snapkit | snapkit is pinned to a raw revision. | Use a tagged version where possible. |
| info | exactVersionDependency | alamofire | alamofire is pinned to exact version 5.4.0. | This may be intentional, but it can block patch updates. |

</details>
```

### JSON Output

Use JSON when you want stable automation and baselines.

```sh
swift-package-audit scan --format json
```

```json
{
  "schemaVersion": 1,
  "rootPath": "/Users/chrisleonard/Desktop/TESTPROJ",
  "workspacePaths": [
    "/Users/chrisleonard/Desktop/TESTPROJ/SwiftPackageAuditPlayground.xcworkspace"
  ],
  "resolvedFilePaths": [
    "/Users/chrisleonard/Desktop/TESTPROJ/Package.resolved"
  ],
  "diagnostics": [
    {
      "id": "e6c165bfc92df4b0",
      "rule": "duplicateURLForms",
      "severity": "warning",
      "packageIdentity": "nimble"
    },
    {
      "id": "f04911d18fbf63aa",
      "rule": "branchDependency",
      "severity": "warning",
      "packageIdentity": "lottie-spm"
    }
  ]
}
```

## Configuration

Swift Package Audit automatically reads `SwiftPackageAudit.yml` from the scan root when present. A config path can also be supplied explicitly:

```sh
swift-package-audit scan --config SwiftPackageAudit.yml
```

Supported config:

```yaml
failOn:
  - missingPackageResolved
  - branchDependency

allow:
  branchDependencies:
    - InternalDesignSystem

ignore:
  packages:
    - SomeLegacyPackage
  rules:
    - exactVersionDependency

rules:
  requirePackageResolved: true
  allowExactVersions: false
```

## Baselines

Use baselines when adopting Swift Package Audit in a project with existing known issues:

```sh
swift-package-audit scan --write-baseline SwiftPackageAuditBaseline.json
swift-package-audit scan --baseline SwiftPackageAuditBaseline.json --fail-on warning
```

Baseline-matched findings are reported as suppressed diagnostics in JSON and PR comment output.

## Optional Version Checks

Swift Package Audit does not contact package hosts during normal scans. To opt in to remote tag checks, run:

```sh
swift-package-audit scan --check
```

This uses `git ls-remote --tags --refs` for packages that already have a version in `Package.resolved`. Swift Package Audit compares stable semantic version tags against the pinned version and reports findings like:

```text
! alamofire
   alamofire is on 5.4.0; latest is 5.12.0 (23 release tags behind: 5.4.1, 5.4.2, 5.4.3, 5.4.4, 5.5.0, 5.6.0, 5.6.1, 5.6.2, 5.6.3, 5.6.4, 5.7.0, 5.7.1, 5.8.0, 5.8.1, 5.9.0, 5.9.1, 5.10.0, 5.10.1, 5.10.2, 5.11.0, 5.11.1, 5.11.2, 5.12.0). 8 minor releases, 4 patch releases behind. The existing exactVersion requirement does not allow the latest version.
   Suggestion: Review the package release notes and update when ready.

Version checks:
  i swift-argument-parser
     Current: 1.8.2, no newer release tags found.
  ! firebase-ios-sdk
     Could not check 10.0.0: Timed out checking tags for https://github.com/firebase/firebase-ios-sdk.git
```

Prerelease tags are ignored in this first version-check implementation. Swift Package Audit also reports whether the existing Xcode package requirement appears to allow the latest version. Network failures are reported per package instead of aborting the whole scan.

## GitHub Actions

Example dependency health check:

```yaml
name: Swift Package Audit

on:
  pull_request:

jobs:
  swift-package-audit:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v5
      - run: swift run swift-package-audit scan --format pr-comment --fail-on error
```

This repository also runs `swift build` and `swift test` in CI.

## Roadmap
See [ROADMAP.md](ROADMAP.md) for planned features.

## License
Swift Package Audit is released under the MIT License.
