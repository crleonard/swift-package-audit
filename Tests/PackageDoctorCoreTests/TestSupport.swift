import Foundation

@testable import PackageDoctorCore

func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("PackageDoctorTests")
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func write(_ contents: String, to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try contents.write(to: url, atomically: true, encoding: .utf8)
}

func pbxproj(packageBlocks: String) -> String {
    """
    // !$*UTF8*$!
    {
      objects = {
    \(packageBlocks)
      };
    }
    """
}

func packageReferenceBlock(
    id: String = "1234567890ABCDEF12345678",
    url: String,
    requirement: String
) -> String {
    """
        \(id) /* XCRemoteSwiftPackageReference "Package" */ = {
          isa = XCRemoteSwiftPackageReference;
          repositoryURL = "\(url)";
          requirement = {
            \(requirement)
          };
        };
    """
}

func productBlock() -> String {
    """
        0987654321ABCDEF12345678 /* Lottie */ = {
          isa = XCSwiftPackageProductDependency;
          package = 1234567890ABCDEF12345678 /* XCRemoteSwiftPackageReference "Package" */;
          productName = Lottie;
        };
    """
}

func modernResolved(_ pins: String) -> String {
    """
    {
      "originHash" : "abc",
      "pins" : [
    \(pins)
      ],
      "version" : 3
    }
    """
}

func resolvedPin(
    identity: String,
    location: String,
    version: String? = "1.0.0",
    revision: String = "abcdef",
    branch: String? = nil
) -> String {
    var state = """
          "revision" : "\(revision)"
    """
    if let version {
        state += ",\n        \"version\" : \"\(version)\""
    }
    if let branch {
        state += ",\n        \"branch\" : \"\(branch)\""
    }

    return """
        {
          "identity" : "\(identity)",
          "kind" : "remoteSourceControl",
          "location" : "\(location)",
          "state" : {
    \(state)
          }
        }
    """
}
