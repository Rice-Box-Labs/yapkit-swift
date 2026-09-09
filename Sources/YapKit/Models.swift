import Foundation

public struct YapUser: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String?
    public let avatarURL: URL?
    public init(id: String, displayName: String? = nil, avatarURL: URL? = nil) { self.id = id; self.displayName = displayName; self.avatarURL = avatarURL }
    enum CodingKeys: String, CodingKey { case id, displayName = "display_name", avatarURL = "avatar_url" }
}

public enum YapChannelKind: String, Codable, Hashable, Sendable { case direct, group }

public struct YapChannelMember: Codable, Identifiable, Hashable, Sendable {
    public let user: YapUser; public let role: String; public var id: String { user.id }
    public init(user: YapUser, role: String = "member") { self.user = user; self.role = role }
}

public struct YapMessagePreview: Codable, Hashable, Sendable {
    public let id: String; public let userId: String; public let text: String
    public init(id: String, userId: String, text: String) { self.id = id; self.userId = userId; self.text = text }
}

public enum YapAttachmentKind: String, Codable, Hashable, Sendable { case image, file }
public struct YapAttachment: Codable, Identifiable, Hashable, Sendable {
    public let id: String; public let kind: YapAttachmentKind; public let fileName: String; public let mimeType: String; public let byteCount: Int; public let url: URL?; public let thumbnailURL: URL?
    public init(id: String, kind: YapAttachmentKind, fileName: String, mimeType: String, byteCount: Int, url: URL? = nil, thumbnailURL: URL? = nil) { self.id = id; self.kind = kind; self.fileName = fileName; self.mimeType = mimeType; self.byteCount = byteCount; self.url = url; self.thumbnailURL = thumbnailURL }
    enum CodingKeys: String, CodingKey { case id, kind, fileName = "file_name", mimeType = "mime_type", byteCount = "byte_count", url, thumbnailURL = "thumbnail_url" }
}

public struct YapReaction: Codable, Hashable, Sendable {
    public let emoji: String; public let count: Int; public let reactedByCurrentUser: Bool
    public init(emoji: String, count: Int, reactedByCurrentUser: Bool = false) { self.emoji = emoji; self.count = count; self.reactedByCurrentUser = reactedByCurrentUser }
    enum CodingKeys: String, CodingKey { case emoji, count, reactedByCurrentUser = "reacted_by_current_user" }
}
public struct YapReadReceipt: Codable, Hashable, Sendable {
    public let user: YapUser; public let sequence: Int
    public init(user: YapUser, sequence: Int) { self.user = user; self.sequence = sequence }
}

public struct YapMessage: Codable, Identifiable, Hashable, Sendable {
    public let id: String; public let userId: String; public let text: String; public let sequence: Int; public let createdAt: Date
    public var deliveryState: YapMessageDeliveryState; public let clientID: String?; public let replyTo: YapMessagePreview?; public let attachments: [YapAttachment]; public let reactions: [YapReaction]; public let readReceipts: [YapReadReceipt]; public let editedAt: Date?; public let isDeleted: Bool
    public init(id: String, userId: String, text: String, sequence: Int, createdAt: Date, deliveryState: YapMessageDeliveryState = .sent, clientID: String? = nil, replyTo: YapMessagePreview? = nil, attachments: [YapAttachment] = [], reactions: [YapReaction] = [], readReceipts: [YapReadReceipt] = [], editedAt: Date? = nil, isDeleted: Bool = false) { self.id = id; self.userId = userId; self.text = text; self.sequence = sequence; self.createdAt = createdAt; self.deliveryState = deliveryState; self.clientID = clientID; self.replyTo = replyTo; self.attachments = attachments; self.reactions = reactions; self.readReceipts = readReceipts; self.editedAt = editedAt; self.isDeleted = isDeleted }
    enum CodingKeys: String, CodingKey { case id, userId = "user_id", text, sequence, createdAt = "created_at", clientID = "client_id", replyTo = "reply_to", attachments, reactions, readReceipts = "read_receipts", editedAt = "edited_at", isDeleted = "is_deleted" }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self); id = try c.decode(String.self, forKey: .id); userId = try c.decode(String.self, forKey: .userId); text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""; sequence = try c.decode(Int.self, forKey: .sequence); createdAt = try c.decode(Date.self, forKey: .createdAt); deliveryState = .sent; clientID = try c.decodeIfPresent(String.self, forKey: .clientID); replyTo = try? c.decode(YapMessagePreview.self, forKey: .replyTo); attachments = (try? c.decode([YapAttachment].self, forKey: .attachments)) ?? []; reactions = (try? c.decode([YapReaction].self, forKey: .reactions)) ?? []; readReceipts = (try? c.decode([YapReadReceipt].self, forKey: .readReceipts)) ?? []; editedAt = try? c.decode(Date.self, forKey: .editedAt); isDeleted = try c.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
    }
}
public enum YapMessageDeliveryState: String, Equatable, Hashable, Sendable { case sending, sent, failed }

public struct YapChannel: Codable, Identifiable, Hashable, Sendable {
    public let id: String; public let tenantId: String; public let kind: YapChannelKind; public let name: String?; public let members: [YapChannelMember]; public let latestSequence: Int; public let latestMessageAt: Date?; public let latestMessageText: String?; public let latestMessageSenderID: String?; public let unreadCount: Int; public let createdAt: Date
    public init(id: String, tenantId: String, kind: YapChannelKind = .direct, name: String? = nil, members: [YapChannelMember] = [], latestSequence: Int = 0, latestMessageAt: Date? = nil, latestMessageText: String? = nil, latestMessageSenderID: String? = nil, unreadCount: Int = 0, createdAt: Date = .now) { self.id = id; self.tenantId = tenantId; self.kind = kind; self.name = name; self.members = members; self.latestSequence = latestSequence; self.latestMessageAt = latestMessageAt; self.latestMessageText = latestMessageText; self.latestMessageSenderID = latestMessageSenderID; self.unreadCount = unreadCount; self.createdAt = createdAt }
    enum CodingKeys: String, CodingKey { case id, tenantId = "tenant_id", kind, name, members, latestSequence = "latest_sequence", latestMessageAt = "latest_message_at", latestMessageText = "latest_message_text", latestMessageSenderID = "latest_message_sender_id", unreadCount = "unread_count", createdAt = "created_at" }
    public init(from decoder: Decoder) throws { let c = try decoder.container(keyedBy: CodingKeys.self); id = try c.decode(String.self, forKey: .id); tenantId = try c.decode(String.self, forKey: .tenantId); kind = try c.decodeIfPresent(YapChannelKind.self, forKey: .kind) ?? .direct; name = try c.decodeIfPresent(String.self, forKey: .name); members = try c.decodeIfPresent([YapChannelMember].self, forKey: .members) ?? []; latestSequence = try c.decodeIfPresent(Int.self, forKey: .latestSequence) ?? 0; latestMessageAt = try c.decodeIfPresent(Date.self, forKey: .latestMessageAt); latestMessageText = try c.decodeIfPresent(String.self, forKey: .latestMessageText); latestMessageSenderID = try c.decodeIfPresent(String.self, forKey: .latestMessageSenderID); unreadCount = try c.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0; createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now }
}

public struct YapUploadProgress: Sendable, Equatable { public let attachmentId: String; public let completedBytes: Int; public let totalBytes: Int; public var fractionCompleted: Double { totalBytes == 0 ? 0 : Double(completedBytes) / Double(totalBytes) } }
public struct YapSearchResult: Codable, Identifiable, Sendable, Hashable { public let id: String; public let message: YapMessage; public init(id: String, message: YapMessage) { self.id = id; self.message = message } }
public struct YapCapabilities: Codable, Sendable, Hashable { public let groups: Bool; public let attachments: Bool; public let reactions: Bool; public let editing: Bool; public let search: Bool; public init(groups: Bool = true, attachments: Bool = true, reactions: Bool = true, editing: Bool = true, search: Bool = true) { self.groups = groups; self.attachments = attachments; self.reactions = reactions; self.editing = editing; self.search = search } }
public enum YapAPNsEnvironment: String, Codable, Sendable { case sandbox, production }
public enum YapConnectionState: Equatable, Sendable { case disconnected, connecting, connected, reconnecting, failed(String) }
public enum YapError: Error, Equatable, Sendable { case unauthorized, forbidden, invalidRequest, server(code: String), transport(String) }
extension YapError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unauthorized: "YapKit authentication expired or was rejected."
        case .forbidden: "YapKit rejected this operation because the user or conversation is not accessible."
        case .invalidRequest: "YapKit rejected an invalid request."
        case .server(let code): "YapKit server error (\(code))."
        case .transport(let message): "YapKit transport error: \(message)"
        }
    }
}
public enum YapSocketEvent: Sendable { case ready(nextSequence: Int); case messageCreated(YapMessage); case acknowledgement(YapMessage); case messageUpdated(YapMessage); case reactionUpdated(YapMessage); case read(userId: String, sequence: Int); case typing(userId: String, isTyping: Bool); case failure(code: String) }
public enum YapInboxSocketEvent: Sendable { case ready(version: Int); case channelsChanged(version: Int); case failure(code: String) }
