# Swift Package Audit

A SwiftPM health checker for real Xcode projects.

Swift Package Audit diagnoses dependency health issues in Xcode SwiftPM setups by comparing what your project asks for against what Package.resolved actually pins.

Status: release candidate. Swift Package Audit is read-only, does not update packages, and does not edit `project.pbxproj` files.

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

Build from source:

```sh
git clone https://github.com/crleonard/swift-package-audit.git
cd swift-package-audit
swift build -c release
```

Run the built executable:

```sh
.build/release/swift-package-audit scan --path /path/to/project
```

Install with Mint:

```sh
mint install crleonard/swift-package-audit
```

Homebrew support is planned for a future release.

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

## Example Output

```text
Swift Package Audit

Path:
  /Users/chris/project

Projects:
  MyApp.xcodeproj

Swift packages:
  12 referenced
  12 resolved

Health:
  1 info
  3 warnings
  1 errors

Errors:
  x Firebase
     firebase-ios-sdk is referenced by the Xcode project, but it is missing from Package.resolved.
     Suggestion: Run xcodebuild -resolvePackageDependencies.

Warnings:
  ! Lottie
     lottie-spm is pinned to branch 'main'.
     Suggestion: Prefer a versioned release for reproducible builds.
```

Markdown output is designed for general reports. `pr-comment` output is designed for GitHub pull request comments. JSON output is pretty-printed with sorted keys and uses schema version `1`; see [Docs/JSON_SCHEMA.md](Docs/JSON_SCHEMA.md).

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
Package is on 1.0.0; latest is 2.0.0 (4 release tags behind: 1.1.0, 1.2.0, 1.2.1, 2.0.0).
1 major release, 2 minor releases behind. The existing upToNextMajorVersion requirement does not allow the latest version.
```

Prerelease tags are ignored in this first version-check implementation. Swift Package Audit also reports whether the existing Xcode package requirement appears to allow the latest version.

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
      - uses: actions/checkout@v4
      - run: swift run swift-package-audit scan --format pr-comment --fail-on error
```

This repository also runs `swift build` and `swift test` in CI.

## Roadmap

Swift Package Audit is ready for 1.0 release validation. Planned post-1.0 work includes:

- stale dependency checks
- latest release checks
- license checks
- CocoaPods support
- Carthage support
- security advisory checks
- optional fix commands

## License

Swift Package Audit is released under the MIT License.
