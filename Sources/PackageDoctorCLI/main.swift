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

    @Option(name: .long, help: "Output format: text, json, or markdown.")
    var format: OutputFormat = .text

    @Option(name: .long, help: "Exit non-zero when diagnostics are at least this severity.")
    var failOn: DiagnosticSeverity?

    @Flag(name: .long, help: "Equivalent to --fail-on warning.")
    var strict = false

    func run() throws {
        let result = PackageDoctorScanner().scan(
            configuration: ScanConfiguration(path: path, strict: strict)
        )
        let renderer = ReportRendererFactory.renderer(for: format)
        print(try renderer.render(result), terminator: "")

        let threshold = strict ? DiagnosticSeverity.warning : failOn
        if let threshold, result.diagnostics.contains(where: { $0.severity >= threshold }) {
            throw ExitCode.failure
        }
    }
}

extension OutputFormat: ExpressibleByArgument {}
extension DiagnosticSeverity: ExpressibleByArgument {}
