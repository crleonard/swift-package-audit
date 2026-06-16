# Contributing

Thanks for your interest in Swift Package Audit.
Swift Package Audit is pre-1.0 and currently read-only. Contributions should preserve that boundary unless a future milestone explicitly introduces write or fix operations.

## Development

```sh
swift build
swift test
```

The package uses Swift 6, Swift Argument Parser for the CLI, and Swift Testing for the test suite.

## Guidelines

- Keep parsing defensive and understandable.
- Prefer fixtures over assumptions about one local Xcode version.
- Avoid network access in normal scans.
- Do not edit project files as part of scanning.
- Keep JSON output stable.
- Add or update tests for parser, diagnostic, reporting, and CLI-facing behavior when changing those areas.

## Commit Style

Use concise conventional commit-style subjects, for example:

```text
feat: add dependency health diagnostics
fix: parse quoted repository URLs
test: add workspace fixture coverage
docs: clarify pre-1.0 status
```
