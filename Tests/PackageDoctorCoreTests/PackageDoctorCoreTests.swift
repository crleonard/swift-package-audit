import Testing

@testable import PackageDoctorCore

@Test
func exposesToolMetadata() {
    #expect(PackageDoctor.name == "PackageDoctor")
    #expect(PackageDoctor.tagline == "A SwiftPM health checker for real Xcode projects.")
}
