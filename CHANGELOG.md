# Changelog

PackageDoctor is in pre-1.0 development. Do not treat any v0.x milestone tag as a production-ready 1.0 release.

## Unreleased

- Continue validating PackageDoctor against real Xcode projects.
- Expand parser fixture coverage.
- Prepare configuration and baseline designs.

## v0.7.0-docs

- Document project status, installation, usage, CI integration, and roadmap.

## v0.6.0-workspaces

- Detect `.xcworkspace` folders.
- Scan multiple `.xcodeproj` folders under a workspace root.

## v0.5.0-cli

- Add `packagedoctor scan`.
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
