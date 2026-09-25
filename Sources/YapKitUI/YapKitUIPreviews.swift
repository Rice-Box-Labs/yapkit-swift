import SwiftUI
import YapKit

#if DEBUG

/// A deterministic in-memory service used only by Xcode previews. It never
/// reaches the network, so previews remain useful while the API is offline.
private struct YapPreviewService: YapChatService, Sendable {
    let previewChannels: [YapChannel]
    let previewMessages: [YapMessage]

    func currentContext() async throws -> YapContext {
        YapContext(userId: "self", appId: "preview", environmentId: "preview", tenantId: "preview")
    }

    func capabilities() async throws -> YapCapabilities { .init() }
    func channels(tenantId: String) async throws -> [YapChannel] { previewChannels }
    func users(tenantId: String, query: String) async throws -> [YapUser] { [] }
    func createDirectChannel(otherUserId: String) async throws -> YapChannel { previewChannels[0] }
    func createGroupChannel(name: String, memberIds: [String]) async throws -> YapChannel { previewChannels[0] }
    func deleteChannel(channelId: String) async throws {}
    func messages(channelId: String, after: Int) async throws -> [YapMessage] { previewMessages }
    func searchMessages(channelId: String, query: String) async throws -> [YapSearchResult] { [] }

    func sendMessage(channelId: String, text: String, replyTo: String?, attachments: [String], clientId: String) async throws -> YapMessage {
        YapMessage(id: "preview-send", userId: "self", text: text, sequence: 99, createdAt: .now, clientID: clientId)
    }

    func editMessage(channelId: String, messageId: String, text: String) async throws -> YapMessage {
        previewMessages.first ?? YapMessage(id: messageId, userId: "self", text: text, sequence: 1, createdAt: .now)
    }

    func deleteMessage(channelId: String, messageId: String) async throws {}
    func toggleReaction(channelId: String, messageId: String, emoji: String) async throws -> YapMessage { previewMessages.first! }
    func markChannelRead(channelId: String, through sequence: Int?) async throws {}
    func openChannelSocket(channelId: String, after: Int) async throws -> YapChannelSocket { throw YapError.server(code: "preview") }
    func openInboxSocket() async throws -> YapInboxSocket { throw YapError.server(code: "preview") }
}

private enum YapPreviewFixtures {
    static let members = [
        YapChannelMember(user: YapUser(id: "self", displayName: "You")),
        YapChannelMember(user: YapUser(id: "maya", displayName: "Maya"))
    ]

    static let channel = YapChannel(
        id: "preview-channel",
        tenantId: "preview",
        kind: .direct,
        members: members,
        latestSequence: 3,
        latestMessageAt: .now,
        latestMessageText: "See you Sunday!",
        latestMessageSenderID: "maya",
        unreadCount: 2
    )

    static let messages = [
        YapMessage(id: "preview-1", userId: "maya", text: "Are you coming to the gathering this weekend?", sequence: 1, createdAt: .now.addingTimeInterval(-240)),
        YapMessage(id: "preview-2", userId: "self", text: "Yes! I’ll be there early to help set up.", sequence: 2, createdAt: .now.addingTimeInterval(-180), reactions: [YapReaction(emoji: "❤️", count: 1, reactedByCurrentUser: true)]),
        YapMessage(id: "preview-3", userId: "maya", text: "See you Sunday!", sequence: 3, createdAt: .now.addingTimeInterval(-45))
    ]

    static let service = YapPreviewService(previewChannels: [channel], previewMessages: messages)
}

#Preview("YapKit Inbox") {
    NavigationStack {
        YapInboxView(service: YapPreviewFixtures.service, tenantID: "preview") { _ in }
    }
}

#Preview("YapKit Conversation · Dark") {
    NavigationStack {
        YapConversationView(
            controller: YapChannelController(
                client: YapPreviewFixtures.service,
                channel: YapPreviewFixtures.channel,
                currentUserID: "self"
            )
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("YapKit Composer") {
    YapPreviewComposer()
}

#Preview("YapKit Typing Indicator") {
    YapPreviewTypingIndicator()
}

#Preview("YapKit Typing Indicator · Dark") {
    YapPreviewTypingIndicator()
        .preferredColorScheme(.dark)
}

@MainActor
private struct YapPreviewComposer: View {
    @State private var draft = "Write a thoughtful update…"
    @State private var reply: YapMessage?
    @State private var attachments: [String] = []
    @State private var showingAttachments = false

    var body: some View {
        YapDefaultComposerRenderer().makeBody(
            context: .init(
                draft: $draft,
                replyMessage: $reply,
                stagedAttachmentNames: $attachments,
                isShowingAttachments: $showingAttachments,
                theme: .init(),
                send: {}
            )
        )
        .background(YapTheme().colors.canvas)
    }
}

@MainActor
private struct YapPreviewTypingIndicator: View {
    @State private var activeUserCount = 5

    private let users = [
        YapUser(
            id: "maya",
            displayName: "Maya",
            avatarURL: URL(string: "https://i.pravatar.cc/96?img=47")
        ),
        YapUser(
            id: "jonah",
            displayName: "Jonah",
            avatarURL: URL(string: "https://i.pravatar.cc/96?img=12")
        ),
        YapUser(
            id: "ria",
            displayName: "Ria",
            avatarURL: URL(string: "https://i.pravatar.cc/96?img=32")
        ),
        YapUser(
            id: "theo",
            displayName: "Theo",
            avatarURL: URL(string: "https://i.pravatar.cc/96?img=11")
        ),
        YapUser(
            id: "imani",
            displayName: "Imani",
            avatarURL: URL(string: "https://i.pravatar.cc/96?img=45")
        ),
        YapUser(id: "noah", displayName: "Noah")
    ]

    private var activeUsers: [YapUser] {
        Array(users.prefix(activeUserCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if !activeUsers.isEmpty {
                    typingIndicator(for: activeUsers)
                        .transition(
                            .opacity.combined(
                                with: .scale(scale: 0.92, anchor: .leading)
                            )
                        )
                }
            }
            .animation(
                .spring(response: 0.42, dampingFraction: 0.82),
                value: activeUserCount
            )

            Stepper(
                "People typing: \(activeUserCount)",
                value: $activeUserCount,
                in: 0...users.count
            )
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
        .background(YapTheme().colors.canvas)
    }

    private func typingIndicator(for users: [YapUser]) -> some View {
        YapDefaultTypingIndicatorRenderer().makeBody(
            context: .init(
                userIDs: Set(users.map(\.id)),
                typingUsers: users,
                channelKind: .group,
                theme: .init()
            )
        )
    }
}

#endif
