import XCTest
@testable import YapKit

final class YapKitTests: XCTestCase {
    func testStaticTokenProvider() async throws { let token = try await StaticYapTokenProvider(token: "token").accessToken(); XCTAssertEqual(token, "token") }
    func testProductionEnvironmentUsesHostedAPI() { let client = YapClient(authentication: .serverTokenProvider(StaticYapTokenProvider(token: "token"))); XCTAssertEqual(client.baseURL.absoluteString, "https://api.yapkit.cloud") }
    func testCustomEnvironmentUsesProvidedURL() { let client = YapClient(environment: .custom(URL(string: "http://127.0.0.1:8787")!), authentication: .serverTokenProvider(StaticYapTokenProvider(token: "token"))); XCTAssertEqual(client.baseURL.absoluteString, "http://127.0.0.1:8787") }
    func testMessageDecoding() throws { let json = #"{"id":"m1","user_id":"u1","text":"hello","sequence":1,"created_at":1700000000000}"#.data(using: .utf8)!; let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970; XCTAssertEqual(try decoder.decode(YapMessage.self, from: json).text, "hello") }
    func testMessageDecodingPreservesClientCorrelationID() throws {
        let json = #"{"id":"m1","user_id":"u1","text":"hello","sequence":1,"created_at":1700000000000,"client_id":"local-send-1"}"#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        XCTAssertEqual(try decoder.decode(YapMessage.self, from: json).clientID, "local-send-1")
    }
    func testRichMessageDefaultsRemainCompatible() throws { let json = #"{"id":"m1","user_id":"u1","text":"hello","sequence":1,"created_at":1700000000000,"reactions":[{"emoji":"👍","count":2,"reacted_by_current_user":true}]}"#.data(using: .utf8)!; let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970; let message = try decoder.decode(YapMessage.self, from: json); XCTAssertEqual(message.reactions.first?.count, 2); XCTAssertTrue(message.reactions.first?.reactedByCurrentUser == true); XCTAssertTrue(message.attachments.isEmpty) }
    func testGroupChannelDecoding() throws { let json = #"{"id":"c1","tenant_id":"t1","kind":"group","name":"Weekend Crew","members":[{"user":{"id":"u1","display_name":"Maya"},"role":"member"}],"created_at":1700000000000}"#.data(using: .utf8)!; let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970; let channel = try decoder.decode(YapChannel.self, from: json); XCTAssertEqual(channel.kind, .group); XCTAssertEqual(channel.name, "Weekend Crew"); XCTAssertEqual(channel.members.count, 1) }
    func testWebSocketURLUsesSecureSocketSchemeAndCursor() { let client = YapClient(baseURL: URL(string: "https://api.yapkit.dev")!, authentication: .serverTokenProvider(StaticYapTokenProvider(token: "token"))); XCTAssertEqual(client.webSocketURL(channelId: "channel-1", after: 42).absoluteString, "wss://api.yapkit.dev/v1/channels/channel-1/connect?after=42") }
    func testInboxWebSocketURLUsesSecureSocketScheme() { let client = YapClient(baseURL: URL(string: "https://api.yapkit.dev")!, authentication: .serverTokenProvider(StaticYapTokenProvider(token: "token"))); XCTAssertEqual(client.inboxWebSocketURL().absoluteString, "wss://api.yapkit.dev/v1/inbox/connect") }
    func testInboxTreatsMessageMutationsAsChannelInvalidations() throws {
        let payload = #"{"type":"message.created","version":7}"#.data(using: .utf8)!
        guard case .channelsChanged(let version) = try YapInboxSocket.decodeEvent(from: payload) else {
            return XCTFail("Expected a channel invalidation")
        }
        XCTAssertEqual(version, 7)
    }
    func testURLResolutionPreservesQueryString() { let client = YapClient(baseURL: URL(string: "https://api.yapkit.dev")!, authentication: .serverTokenProvider(StaticYapTokenProvider(token: "token"))); XCTAssertEqual(client.url(for: "/v1/channels?tenantId=tenant-1").absoluteString, "https://api.yapkit.dev/v1/channels?tenantId=tenant-1") }
}
