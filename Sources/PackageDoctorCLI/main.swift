import ArgumentParser
import PackageDoctorCore

@main
struct PackageDoctorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "packagedoctor",
        abstract: PackageDoctor.tagline
    )

    func run() {
        print(PackageDoctor.name)
    }
}
