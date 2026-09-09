import Foundation

public protocol YapTokenProvider: Sendable { func accessToken() async throws -> String }
public enum YapAuthentication: Sendable {
    case serverTokenProvider(any YapTokenProvider)
    case oidcHostTokenProvider(any YapTokenProvider)
    var provider: any YapTokenProvider { switch self { case .serverTokenProvider(let p), .oidcHostTokenProvider(let p): p } }
}

public struct StaticYapTokenProvider: YapTokenProvider { public let token: String; public init(token: String) { self.token = token }; public func accessToken() async throws -> String { token } }
