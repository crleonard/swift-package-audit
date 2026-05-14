// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PackageDoctor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PackageDoctorCore",
            targets: ["PackageDoctorCore"]
        ),
        .executable(
            name: "packagedoctor",
            targets: ["PackageDoctorCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0")
    ],
    targets: [
        .target(
            name: "PackageDoctorCore"
        ),
        .executableTarget(
            name: "PackageDoctorCLI",
            dependencies: [
                "PackageDoctorCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "PackageDoctorCoreTests",
            dependencies: ["PackageDoctorCore"]
        ),
    ]
)
