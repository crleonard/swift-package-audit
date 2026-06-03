import ArgumentParser
import Foundation
import PackageDoctorCore

@main
struct PackageDoctorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "packagedoctor",
        abstract: PackageDoctor.tagline,
        subcommands: [Scan.self],
        defaultSubcommand: Scan.self
    )
}

struct Scan: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "Scan an Xcode or SwiftPM directory for dependency health issues."
    )

    @Option(name: .long, help: "Directory to scan.")
    var path = "."

    @Option(name: .long, help: "Output format: text, json, markdown, or pr-comment.")
    var format: OutputFormat = .text

    @Option(name: .long, help: "Exit non-zero when diagnostics are at least this severity.")
    var failOn: DiagnosticSeverity?

    @Option(name: .long, help: "Path to PackageDoctor.yml.")
    var config: String?

    @Option(name: .long, help: "Path to a PackageDoctor baseline JSON file.")
    var baseline: String?

    @Option(name: .long, help: "Write the current active diagnostics to a baseline JSON file.")
    var writeBaseline: String?

    @Flag(name: .long, help: "Equivalent to --fail-on warning.")
    var strict = false

    func run() throws {
        let scanner = PackageDoctorScanner()
        let configuration = ScanConfiguration(
            path: path,
            strict: strict,
            configPath: config,
            baselinePath: writeBaseline == nil ? baseline : nil
        )
        let result = scanner.scan(configuration: configuration)

        if let writeBaseline {
            let baseline = DiagnosticBaseline(
                diagnostics: result.diagnostics.map(BaselineEntry.init(diagnostic:))
            )
            try DiagnosticBaselineStore().write(baseline, path: writeBaseline)
        }

        let renderer = ReportRendererFactory.renderer(for: format)
        print(try renderer.render(result), terminator: "")

        let configuredFailRules = configuredFailRules(scanner: scanner, configuration: configuration)
        let threshold = strict ? DiagnosticSeverity.warning : failOn
        let shouldFailForSeverity = threshold.map { threshold in
            result.diagnostics.contains(where: { $0.severity >= threshold })
        } ?? false
        let shouldFailForRule = result.diagnostics.contains { configuredFailRules.contains($0.rule) }

        if shouldFailForSeverity || shouldFailForRule {
            throw ExitCode.failure
        }
    }

    private func configuredFailRules(
        scanner: PackageDoctorScanner,
        configuration: ScanConfiguration
    ) -> [DiagnosticRule] {
        guard let configPath = scanner.resolvedConfigPath(configuration: configuration),
            let config = try? PackageDoctorConfigLoader().load(path: configPath)
        else {
            return []
        }

        return config.failOn
    }
}

extension OutputFormat: ExpressibleByArgument {}
extension DiagnosticSeverity: ExpressibleByArgument {}
