import Foundation

public protocol YapChatService: Sendable {
    func currentContext() async throws -> YapContext
    func capabilities() async throws -> YapCapabilities
    func channels(tenantId: String) async throws -> [YapChannel]
    func users(tenantId: String, query: String) async throws -> [YapUser]
    func createDirectChannel(otherUserId: String) async throws -> YapChannel
    func createGroupChannel(name: String, memberIds: [String]) async throws -> YapChannel
    func deleteChannel(channelId: String) async throws
    func messages(channelId: String, after: Int) async throws -> [YapMessage]
    func searchMessages(channelId: String, query: String) async throws -> [YapSearchResult]
    func sendMessage(channelId: String, text: String, replyTo: String?, attachments: [String], clientId: String) async throws -> YapMessage
    func editMessage(channelId: String, messageId: String, text: String) async throws -> YapMessage
    func deleteMessage(channelId: String, messageId: String) async throws
    func toggleReaction(channelId: String, messageId: String, emoji: String) async throws -> YapMessage
    func markChannelRead(channelId: String, through sequence: Int?) async throws
    func openChannelSocket(channelId: String, after: Int) async throws -> YapChannelSocket
    func openInboxSocket() async throws -> YapInboxSocket
}

public extension YapChatService {
    func sendMessage(channelId: String, text: String, replyTo: String? = nil, attachments: [String] = [], clientId: String = UUID().uuidString) async throws -> YapMessage { try await sendMessage(channelId: channelId, text: text, replyTo: replyTo, attachments: attachments, clientId: clientId) }
    func messages(channelId: String) async throws -> [YapMessage] { try await messages(channelId: channelId, after: 0) }
    func openInboxSocket() async throws -> YapInboxSocket { throw YapError.server(code: "inbox_realtime_unavailable") }
}
