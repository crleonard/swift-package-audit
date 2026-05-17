import Foundation

public enum PackageResolvedParserError: Error, CustomStringConvertible, Sendable {
    case unreadable(URL, String)
    case invalidJSON(URL, String)
    case unsupportedSchema(URL)

    public var description: String {
        switch self {
        case .unreadable(let url, let reason):
            "Could not read Package.resolved at \(url.path): \(reason)"
        case .invalidJSON(let url, let reason):
            "Could not parse Package.resolved at \(url.path): \(reason)"
        case .unsupportedSchema(let url):
            "Package.resolved at \(url.path) did not contain a supported pins array."
        }
    }
}

public struct PackageResolvedParser: Sendable {
    private let decoder = JSONDecoder()

    public init() {}

    public func parse(fileURL: URL) throws -> [ResolvedPackage] {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw PackageResolvedParserError.unreadable(fileURL, error.localizedDescription)
        }

        do {
            let document = try decoder.decode(ResolvedDocument.self, from: data)
            guard let pins = document.object?.pins ?? document.pins else {
                throw PackageResolvedParserError.unsupportedSchema(fileURL)
            }

            return pins.map { pin in
                ResolvedPackage(
                    identity: pin.identity ?? pin.package ?? PackageURLNormalizer.normalize(pin.location).identity,
                    location: pin.location,
                    version: pin.state.version,
                    revision: pin.state.revision,
                    branch: pin.state.branch,
                    resolvedFilePath: fileURL.path
                )
            }
        } catch let error as PackageResolvedParserError {
            throw error
        } catch {
            throw PackageResolvedParserError.invalidJSON(fileURL, error.localizedDescription)
        }
    }
}

private struct ResolvedDocument: Decodable {
    var object: ResolvedObject?
    var pins: [ResolvedPin]?
}

private struct ResolvedObject: Decodable {
    var pins: [ResolvedPin]
}

private struct ResolvedPin: Decodable {
    var identity: String?
    var package: String?
    var location: String
    var state: ResolvedState

    enum CodingKeys: String, CodingKey {
        case identity
        case package
        case location
        case repositoryURL
        case state
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identity = try container.decodeIfPresent(String.self, forKey: .identity)
        package = try container.decodeIfPresent(String.self, forKey: .package)
        location =
            try container.decodeIfPresent(String.self, forKey: .location)
            ?? container.decode(String.self, forKey: .repositoryURL)
        state = try container.decode(ResolvedState.self, forKey: .state)
    }
}

private struct ResolvedState: Decodable {
    var version: String?
    var revision: String?
    var branch: String?
}
