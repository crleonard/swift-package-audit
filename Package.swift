// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftPackageAudit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SwiftPackageAuditCore",
            targets: ["SwiftPackageAuditCore"]
        ),
        .executable(
            name: "swift-package-audit",
            targets: ["SwiftPackageAuditCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2")
    ],
    targets: [
        .target(
            name: "SwiftPackageAuditCore"
        ),
        .executableTarget(
            name: "SwiftPackageAuditCLI",
            dependencies: [
                "SwiftPackageAuditCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "SwiftPackageAuditCoreTests",
            dependencies: ["SwiftPackageAuditCore"]
        ),
    ]
)
