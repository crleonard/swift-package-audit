# Changelog

Swift Package Audit is in pre-1.0 development. Do not treat any v0.x milestone tag as a production-ready 1.0 release.

## v1.0.0

- Rename remaining internal targets, modules, and public symbols to SwiftPackageAudit.
- Add schema-versioned JSON output with stable diagnostic IDs.
- Add `SwiftPackageAudit.yml` config support.
- Add diagnostic baseline read/write support.
- Add `pr-comment` output for GitHub pull request workflows.
- Add optional `--check` remote tag version checks.
- Report whether latest versions satisfy existing Xcode package requirements.
- Classify version-check distance by major, minor, and patch release counts.
- Improve `.xcworkspace` parsing by reading `contents.xcworkspacedata` project references.
- Expand tests for config, baselines, PR comments, schema fields, and workspace layouts.

## Unreleased

- Continue validating Swift Package Audit against additional real-world Xcode projects.

## v0.7.0-docs

- Document project status, installation, usage, CI integration, and roadmap.

## v0.6.0-workspaces

- Detect `.xcworkspace` folders.
- Scan multiple `.xcodeproj` folders under a workspace root.

## v0.5.0-cli

- Add `swift-package-audit scan`.
- Support text, JSON, and Markdown output.
- Support `--fail-on` and `--strict`.

## v0.4.0-reporting

- Add text output for terminals.
- Add stable JSON output for automation.
- Add Markdown output for PR comments.

## v0.3.0-diagnostics

- Add dependency health diagnostics for the MVP rules.

## v0.2.0-parsers

- Parse `Package.resolved` pins.
- Parse Xcode Swift package references from `project.pbxproj`.

## v0.1.0-bootstrap

- Bootstrap the Swift package, CLI target, README skeleton, CI skeleton, and MIT license.
