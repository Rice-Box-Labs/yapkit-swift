import Foundation

public final class YapClient: YapChatService, Sendable {
    public let baseURL: URL; private let auth: YapAuthentication; private let session: URLSession
    private let decoder: JSONDecoder
    public convenience init(environment: YapEnvironment = .production, authentication: YapAuthentication, session: URLSession = .shared) {
        self.init(baseURL: environment.baseURL, authentication: authentication, session: session)
    }
    public init(baseURL: URL, authentication: YapAuthentication, session: URLSession = .shared) { self.baseURL = baseURL; self.auth = authentication; self.session = session; self.decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970 }
    func url(for path: String) -> URL {
        // `URL.appending(path:)` treats `?` as a literal path character and
        // percent-encodes it. Resolve relative URLs instead so query strings
        // reach the API as queries rather than becoming part of the route.
        URL(string: path, relativeTo: baseURL)!.absoluteURL
    }
    func request<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        var request = URLRequest(url: url(for: path)); request.httpMethod = method; request.httpBody = body; request.setValue("application/json", forHTTPHeaderField: "content-type"); request.setValue("Bearer \(try await auth.provider.accessToken())", forHTTPHeaderField: "authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw YapError.transport("invalid response") }
        guard (200..<300).contains(http.statusCode) else { if http.statusCode == 401 { throw YapError.unauthorized }; if http.statusCode == 403 { throw YapError.forbidden }; throw YapError.server(code: String(http.statusCode)) }
        do { return try decoder.decode(T.self, from: data) } catch { throw YapError.transport(error.localizedDescription) }
    }
    public func currentContext() async throws -> YapContext { try await request("/v1/me") }
    public func capabilities() async throws -> YapCapabilities { (try await currentContext()).capabilities }
    public func channels(tenantId: String) async throws -> [YapChannel] { let response: ChannelResponse = try await request("/v1/channels?tenantId=\(tenantId)"); return response.channels }
    public func users(tenantId: String, query: String) async throws -> [YapUser] { let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query; let response: UserResponse = try await request("/v1/users?tenantId=\(tenantId)&query=\(encoded)"); return response.users }
    public func createDirectChannel(otherUserId: String) async throws -> YapChannel { let data = try JSONEncoder().encode(["otherUserId": otherUserId]); let response: SingleChannelResponse = try await request("/v1/channels", method: "POST", body: data); return response.channel }
    public func createGroupChannel(name: String, memberIds: [String]) async throws -> YapChannel { let data = try JSONSerialization.data(withJSONObject: ["kind": "group", "name": name, "memberIds": memberIds]); let response: SingleChannelResponse = try await request("/v1/channels", method: "POST", body: data); return response.channel }
    public func deleteChannel(channelId: String) async throws { _ = try await requestRaw("/v1/channels/\(channelId)", method: "DELETE") }
    public func messages(channelId: String, after: Int = 0) async throws -> [YapMessage] { let response: MessageResponse = try await request("/v1/channels/\(channelId)/messages?after=\(after)"); return response.messages }
    public func searchMessages(channelId: String, query: String) async throws -> [YapSearchResult] { let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query; let response: SearchResponse = try await request("/v1/channels/\(channelId)/messages/search?query=\(encoded)"); return response.results }
    public func sendMessage(channelId: String, text: String, replyTo: String? = nil, attachments: [String] = [], clientId: String = UUID().uuidString) async throws -> YapMessage { var body: [String: Any] = ["text": text, "clientId": clientId]; if let replyTo { body["replyTo"] = replyTo }; if !attachments.isEmpty { body["attachmentIds"] = attachments }; let data = try JSONSerialization.data(withJSONObject: body); let response: SingleMessageResponse = try await request("/v1/channels/\(channelId)/messages", method: "POST", body: data); return response.message }
    public func sendMessage(channelId: String, text: String, clientId: String = UUID().uuidString) async throws -> YapMessage { try await sendMessage(channelId: channelId, text: text, replyTo: nil, attachments: [], clientId: clientId) }
    public func editMessage(channelId: String, messageId: String, text: String) async throws -> YapMessage { let data = try JSONSerialization.data(withJSONObject: ["text": text]); let response: SingleMessageResponse = try await request("/v1/channels/\(channelId)/messages/\(messageId)", method: "PATCH", body: data); return response.message }
    public func deleteMessage(channelId: String, messageId: String) async throws { _ = try await requestRaw("/v1/channels/\(channelId)/messages/\(messageId)", method: "DELETE") }
    public func toggleReaction(channelId: String, messageId: String, emoji: String) async throws -> YapMessage { let data = try JSONSerialization.data(withJSONObject: ["emoji": emoji]); let response: SingleMessageResponse = try await request("/v1/channels/\(channelId)/messages/\(messageId)/reactions", method: "PUT", body: data); return response.message }
    public func markChannelRead(channelId: String, through sequence: Int? = nil) async throws {
        let body = try JSONSerialization.data(withJSONObject: sequence.map { ["sequence": $0] } ?? [:])
        let _: ReadResponse = try await request("/v1/channels/\(channelId)/read", method: "POST", body: body)
    }
    private func requestRaw(_ path: String, method: String) async throws -> Data {
        var request = URLRequest(url: url(for: path)); request.httpMethod = method; request.setValue("Bearer \(try await auth.provider.accessToken())", forHTTPHeaderField: "authorization")
        let (data, response) = try await session.data(for: request); guard let http = response as? HTTPURLResponse else { throw YapError.transport("invalid response") }; guard (200..<300).contains(http.statusCode) else { if http.statusCode == 401 { throw YapError.unauthorized }; if http.statusCode == 403 { throw YapError.forbidden }; throw YapError.server(code: String(http.statusCode)) }; return data
    }
    public func registerApplePushDevice(token: Data, bundleIdentifier: String, environment: YapAPNsEnvironment) async throws {
        let deviceToken = token.map { String(format: "%02x", $0) }.joined()
        let body = try JSONEncoder().encode(AppleDeviceRegistration(deviceToken: deviceToken, bundleIdentifier: bundleIdentifier, environment: environment))
        let _: DeviceRegistrationResponse = try await request("/v1/devices/apple", method: "POST", body: body)
    }
    func webSocketURL(channelId: String, after: Int) -> URL {
        var components = URLComponents(url: url(for: "/v1/channels/\(channelId)/connect"), resolvingAgainstBaseURL: false)!
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.queryItems = [URLQueryItem(name: "after", value: String(after))]
        return components.url!
    }
    public func openChannelSocket(channelId: String, after: Int) async throws -> YapChannelSocket {
        var request = URLRequest(url: webSocketURL(channelId: channelId, after: after))
        request.setValue("Bearer \(try await auth.provider.accessToken())", forHTTPHeaderField: "authorization")
        return YapChannelSocket(task: session.webSocketTask(with: request))
    }
    func inboxWebSocketURL() -> URL {
        var components = URLComponents(url: url(for: "/v1/inbox/connect"), resolvingAgainstBaseURL: false)!
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        return components.url!
    }
    public func openInboxSocket() async throws -> YapInboxSocket {
        var request = URLRequest(url: inboxWebSocketURL())
        request.setValue("Bearer \(try await auth.provider.accessToken())", forHTTPHeaderField: "authorization")
        return YapInboxSocket(task: session.webSocketTask(with: request))
    }
    struct ChannelResponse: Decodable { let channels: [YapChannel] }; struct UserResponse: Decodable { let users: [YapUser] }; struct SingleChannelResponse: Decodable { let channel: YapChannel }; struct MessageResponse: Decodable { let messages: [YapMessage] }; struct SingleMessageResponse: Decodable { let message: YapMessage }; struct SearchResponse: Decodable { let results: [YapSearchResult] }; struct ReadResponse: Decodable { let channelId: String; let lastReadSequence: Int }; struct DeviceRegistrationResponse: Decodable { let registered: Bool }; struct AppleDeviceRegistration: Encodable { let deviceToken: String; let bundleIdentifier: String; let environment: YapAPNsEnvironment }
}

public final class YapChannelSocket: @unchecked Sendable {
    private let task: URLSessionWebSocketTask
    private let decoder: JSONDecoder
    init(task: URLSessionWebSocketTask) { self.task = task; decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970; task.resume() }
    public func cancel() { task.cancel(with: .goingAway, reason: nil) }
    public func receive() async throws -> YapSocketEvent {
        let payload = try await task.receive()
        let data: Data
        switch payload { case .data(let value): data = value; case .string(let value): data = Data(value.utf8); @unknown default: throw YapError.transport("unsupported websocket payload") }
        let event = try decoder.decode(WireEvent.self, from: data)
        switch event.type {
        case "connection.ready": return .ready(nextSequence: event.nextSequence ?? 0)
        case "message.created": return .messageCreated(try event.message())
        case "message.ack": return .acknowledgement(try event.message())
        case "message.updated", "message.deleted": return .messageUpdated(try event.message())
        case "reaction.updated": return .reactionUpdated(try event.message())
        case "channel.read": return .read(userId: event.userId ?? "", sequence: event.sequence ?? 0)
        case "typing": return .typing(userId: event.userId ?? "", isTyping: event.isTyping ?? false)
        case "error": return .failure(code: event.code ?? "unknown")
        default: return .failure(code: "unsupported_event")
        }
    }
}

public final class YapInboxSocket: @unchecked Sendable {
    private let task: URLSessionWebSocketTask
    private let decoder = JSONDecoder()
    init(task: URLSessionWebSocketTask) { self.task = task; task.resume() }
    public func cancel() { task.cancel(with: .goingAway, reason: nil) }
    public func receive() async throws -> YapInboxSocketEvent {
        let payload = try await task.receive()
        let data: Data
        switch payload { case .data(let value): data = value; case .string(let value): data = Data(value.utf8); @unknown default: throw YapError.transport("unsupported websocket payload") }
        return try Self.decodeEvent(from: data)
    }

    static func decodeEvent(from data: Data) throws -> YapInboxSocketEvent {
        let decoder = JSONDecoder()
        let event = try decoder.decode(InboxWireEvent.self, from: data)
        switch event.type {
        case "connection.ready": return .ready(version: event.version ?? 0)
        // Message mutations are also inbox invalidations. Ignoring them made
        // the first new channel appear, while later messages remained stale
        // until the host app was restarted and fetched the list again.
        case "channel.upserted", "channel.removed", "channel.read_updated", "channels.changed", "message.created", "message.updated", "message.deleted", "reaction.updated":
            return .channelsChanged(version: event.version ?? 0)
        case "error": return .failure(code: event.code ?? "unknown")
        default: return .failure(code: "unsupported_event")
        }
    }
}

private struct WireEvent: Decodable {
    let type: String; let id: String?; let userId: String?; let text: String?; let sequence: Int?; let createdAt: Date?; let clientID: String?; let editedAt: Date?; let deleted: Int?; let nextSequence: Int?; let code: String?; let isTyping: Bool?
    enum CodingKeys: String, CodingKey { case type, id, userId = "user_id", text, sequence, createdAt = "created_at", clientID = "client_id", editedAt = "edited_at", deleted, nextSequence, code, isTyping = "is_typing" }
    func message() throws -> YapMessage { guard let id, let userId, let text, let sequence, let createdAt else { throw YapError.transport("invalid message event") }; return YapMessage(id: id, userId: userId, text: text, sequence: sequence, createdAt: createdAt, clientID: clientID, editedAt: editedAt, isDeleted: deleted == 1) }
}

private struct InboxWireEvent: Decodable {
    let type: String
    let version: Int?
    let code: String?
}

public struct YapContext: Codable, Sendable { public let userId: String; public let appId: String; public let environmentId: String; public let tenantId: String; public let capabilities: YapCapabilities; enum CodingKeys: String, CodingKey { case userId, appId, environmentId, tenantId, capabilities }; public init(userId: String, appId: String, environmentId: String, tenantId: String, capabilities: YapCapabilities = .init()) { self.userId = userId; self.appId = appId; self.environmentId = environmentId; self.tenantId = tenantId; self.capabilities = capabilities }; public init(from decoder: Decoder) throws { let c = try decoder.container(keyedBy: CodingKeys.self); userId = try c.decode(String.self, forKey: .userId); appId = try c.decode(String.self, forKey: .appId); environmentId = try c.decode(String.self, forKey: .environmentId); tenantId = try c.decode(String.self, forKey: .tenantId); capabilities = try c.decodeIfPresent(YapCapabilities.self, forKey: .capabilities) ?? .init() } }
