# PackageDoctor

A SwiftPM health checker for real Xcode projects.

PackageDoctor diagnoses dependency health issues in Xcode SwiftPM setups by comparing what your project asks for against what Package.resolved actually pins.

Status: release candidate. PackageDoctor is read-only, does not update packages, and does not edit `project.pbxproj` files.

## Why PackageDoctor Exists

Many iOS and macOS teams do not manage dependencies through `Package.swift` alone. Real Xcode projects often include:

- `.xcodeproj/project.pbxproj`
- `.xcworkspace`
- `Package.resolved` files inside project or workspace folders
- SwiftPM dependencies configured in Xcode
- UIKit, SwiftUI, and mixed UIKit/SwiftUI apps
- multiple projects in one workspace

PackageDoctor is dependency tooling, not UI tooling. It works from project metadata and resolved pins, regardless of whether the app uses UIKit, SwiftUI, or both.

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

PackageDoctor intentionally avoids network calls during normal scans.

## Installation

Build from source:

```sh
git clone https://github.com/crleonard/PackageDoctor.git
cd PackageDoctor
swift build -c release
```

Run the built executable:

```sh
.build/release/packagedoctor scan --path /path/to/project
```

Install with Mint:

```sh
mint install crleonard/PackageDoctor
```

Homebrew support is planned for a future release.

## Usage

```sh
packagedoctor scan
packagedoctor scan --path .
packagedoctor scan --format text
packagedoctor scan --format json
packagedoctor scan --format markdown
packagedoctor scan --format pr-comment
packagedoctor scan --fail-on error
packagedoctor scan --fail-on warning
packagedoctor scan --strict
packagedoctor scan --config PackageDoctor.yml
packagedoctor scan --baseline PackageDoctorBaseline.json
packagedoctor scan --write-baseline PackageDoctorBaseline.json
```

`--strict` is equivalent to `--fail-on warning`.

## Example Output

```text
PackageDoctor

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

PackageDoctor automatically reads `PackageDoctor.yml` from the scan root when present. A config path can also be supplied explicitly:

```sh
packagedoctor scan --config PackageDoctor.yml
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

Use baselines when adopting PackageDoctor in a project with existing known issues:

```sh
packagedoctor scan --write-baseline PackageDoctorBaseline.json
packagedoctor scan --baseline PackageDoctorBaseline.json --fail-on warning
```

Baseline-matched findings are reported as suppressed diagnostics in JSON and PR comment output.

## GitHub Actions

Example dependency health check:

```yaml
name: PackageDoctor

on:
  pull_request:

jobs:
  packagedoctor:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - run: swift run packagedoctor scan --format pr-comment --fail-on error
```

This repository also runs `swift build` and `swift test` in CI.

## Roadmap

PackageDoctor is ready for 1.0 release validation. Planned post-1.0 work includes:

- stale dependency checks
- latest release checks
- license checks
- CocoaPods support
- Carthage support
- security advisory checks
- optional fix commands

## License

PackageDoctor is released under the MIT License.
