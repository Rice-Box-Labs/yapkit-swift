import Foundation

/// The YapKit API environment used by a client.
public enum YapEnvironment: Sendable {
    /// The hosted YapKit production API.
    case production
    /// A custom endpoint for local development, staging, or self-hosted deployments.
    case custom(URL)

    var baseURL: URL {
        switch self {
        case .production: URL(string: "https://api.yapkit.cloud")!
        case .custom(let url): url
        }
    }
}
