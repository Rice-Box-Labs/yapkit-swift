import SwiftUI
import YapKit

#if canImport(UIKit)
    import UIKit
#endif

public struct YapChannelListView: View {
    @State private var controller: YapChannelListController
    @Environment(\.yapUIConfiguration) private var appConfiguration
    private let overrides: YapUIOverrides?
    public let onSelect: (YapChannel) -> Void
    public init(
        controller: YapChannelListController,
        overrides: YapUIOverrides? = nil,
        onSelect: @escaping (YapChannel) -> Void
    ) {
        _controller = State(initialValue: controller)
        self.overrides = overrides
        self.onSelect = onSelect
    }
    public var body: some View {
        let configuration = appConfiguration.resolving(overrides)
        Group {
            if controller.isLoading && controller.channels.isEmpty {
                configuration.inboxStateRenderer.makeBody(
                    context: .init(state: .loading, theme: configuration.theme)
                    {
                        Task { await controller.start() }
                    }
                )
            } else if let error = controller.error, controller.channels.isEmpty
            {
                configuration.inboxStateRenderer.makeBody(
                    context: .init(
                        state: .error(error.localizedDescription),
                        theme: configuration.theme
                    ) {
                        Task { await controller.start() }
                    }
                )
            } else if controller.channels.isEmpty {
                configuration.inboxStateRenderer.makeBody(
                    context: .init(state: .empty, theme: configuration.theme) {
                        Task { await controller.start() }
                    }
                )
            } else {
                List(controller.channels) { channel in
                    Button {
                        onSelect(channel)
                    } label: {
                        configuration.channelRowRenderer.makeBody(
                            context: .init(
                                channel: channel,
                                currentUserID: nil,
                                theme: configuration.theme
                            )
                        )
                    }.buttonStyle(.plain)
                }.listStyle(.plain)
            }
        }
        .scrollContentBackground(.hidden).background(configuration.theme.canvas)
        .task { await controller.start() }.onDisappear {
            controller.disconnect()
        }
    }
}

public struct YapInboxView: View {
    private let service: any YapChatService
    private let tenantID: String
    private let onSelect: (YapChannel) -> Void
    @Environment(\.yapUIConfiguration) private var appConfiguration
    private let overrides: YapUIOverrides?
    @State private var controller: YapChannelListController
    @State private var query = ""
    @State private var showComposer = false
    public init(
        service: any YapChatService,
        tenantID: String,
        overrides: YapUIOverrides? = nil,
        onSelect: @escaping (YapChannel) -> Void
    ) {
        self.service = service
        self.tenantID = tenantID
        self.overrides = overrides
        self.onSelect = onSelect
        _controller = State(
            initialValue: YapChannelListController(
                client: service,
                tenantId: tenantID
            )
        )
    }
    public var body: some View {
        let configuration = appConfiguration.resolving(overrides)
        List {
            if !query.isEmpty {
                Section {
                    ForEach(
                        controller.channels.filter {
                            ($0.name ?? "").localizedCaseInsensitiveContains(
                                query
                            )
                                || ($0.latestMessageText ?? "")
                                    .localizedCaseInsensitiveContains(query)
                        }
                    ) { channel in
                        Button {
                            onSelect(channel)
                        } label: {
                            configuration.channelRowRenderer.makeBody(
                                context: .init(
                                    channel: channel,
                                    currentUserID: nil,
                                    theme: configuration.theme
                                )
                            )
                        }.buttonStyle(.plain)
                    }
                }
            } else if controller.isLoading && controller.channels.isEmpty {
                Section {
                    configuration.inboxStateRenderer.makeBody(
                        context: .init(
                            state: .loading,
                            theme: configuration.theme
                        ) {
                            Task { await controller.start() }
                        }
                    )
                }
            } else if let error = controller.error, controller.channels.isEmpty
            {
                Section {
                    configuration.inboxStateRenderer.makeBody(
                        context: .init(
                            state: .error(error.localizedDescription),
                            theme: configuration.theme
                        ) {
                            Task { await controller.start() }
                        }
                    )
                }
            } else if controller.channels.isEmpty {
                Section {
                    configuration.inboxStateRenderer.makeBody(
                        context: .init(
                            state: .empty,
                            theme: configuration.theme
                        ) {
                            Task { await controller.start() }
                        }
                    )
                }
            } else {
                Section("Recent") {
                    ForEach(controller.channels) { channel in
                        Button {
                            onSelect(channel)
                        } label: {
                            configuration.channelRowRenderer.makeBody(
                                context: .init(
                                    channel: channel,
                                    currentUserID: nil,
                                    theme: configuration.theme
                                )
                            )
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.plain).scrollContentBackground(.hidden).background(
            configuration.theme.canvas
        )
        .searchable(text: $query, prompt: "Search conversations")
        .navigationTitle("Messages")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showComposer = true
                } label: {
                    Image(systemName: "square.and.pencil").foregroundStyle(
                        configuration.theme.accent
                    )
                }.accessibilityLabel("New conversation")
            }
        }
        .sheet(isPresented: $showComposer) {
            YapNewConversationView(service: service, tenantID: tenantID) {
                channel in
                showComposer = false
                onSelect(channel)
            }
        }
        .task { await controller.start() }.onDisappear {
            controller.disconnect()
        }
    }
}

public struct YapConversationView<HeaderAccessory: View>: View {
    @State private var controller: YapChannelController
    @State private var draft = ""
    @State private var replyMessage: YapMessage?
    @State private var editingMessage: YapMessage?
    @State private var stagedAttachmentNames: [String] = []
    @State private var isShowingAttachments = false
    @Environment(\.yapUIConfiguration) private var appConfiguration
    @Environment(\.scenePhase) private var scenePhase
    private let headerAccessory: () -> HeaderAccessory
    private let overrides: YapUIOverrides?
    public init(
        controller: YapChannelController,
        overrides: YapUIOverrides? = nil,
        @ViewBuilder headerAccessory: @escaping () -> HeaderAccessory
    ) {
        _controller = State(initialValue: controller)
        self.overrides = overrides
        self.headerAccessory = headerAccessory
    }
    public var body: some View {
        let configuration = appConfiguration.resolving(overrides)
        let theme = configuration.theme
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        headerAccessory().padding(.horizontal).padding(.top, 8)
                        ForEach(
                            Array(controller.messages.enumerated()),
                            id: \.element.id
                        ) { index, message in
                            configuration.messageRenderer.makeBody(
                                context: .init(
                                    message: message,
                                    previousMessage: index > 0
                                        ? controller.messages[index - 1] : nil,
                                    nextMessage: index < controller.messages
                                        .count - 1
                                        ? controller.messages[index + 1] : nil,
                                    isCurrentUser: message.userId
                                        == controller.currentUserID,
                                    currentUserID: controller.currentUserID,
                                    theme: theme,
                                    reply: { replyMessage = message },
                                    react: { emoji in
                                        Task {
                                            await controller.toggleReaction(
                                                messageID: message.id,
                                                emoji: emoji
                                            )
                                        }
                                    },
                                    edit: { editingMessage = message },
                                    delete: {
                                        Task {
                                            await controller.delete(
                                                messageID: message.id
                                            )
                                        }
                                    },
                                    retry: {
                                        Task {
                                            await controller.retryFailedMessage(
                                                id: message.id
                                            )
                                        }
                                    }
                                )
                            )
                            .id(message.id)
                        }
                        if !controller.typingUserIDs.isEmpty {
                            configuration.typingIndicatorRenderer.makeBody(
                                context: .init(
                                    userIDs: controller.typingUserIDs,
                                    theme: theme
                                )
                            )
                        }
                    }
                    .padding(.bottom, 12)
                }
                .defaultScrollAnchor(.bottom)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
            }
            .background(theme.canvas)
        }
        .safeAreaInset(edge: .bottom) {
            configuration.composerRenderer.makeBody(
                context: .init(
                    draft: $draft,
                    replyMessage: $replyMessage,
                    stagedAttachmentNames: $stagedAttachmentNames,
                    isShowingAttachments: $isShowingAttachments,
                    theme: theme,
                    send: send
                )
            )
        }
        .background(theme.canvas)
        .animatedTabBarHidden()
        .toolbar {
            ToolbarItem(placement: .principal) {
                configuration.headerRenderer.makeBody(
                    context: .init(
                        channel: controller.channel,
                        currentUserID: controller.currentUserID,
                        theme: theme
                    )
                )
            }
            ToolbarItem(placement: .automatic) {
                NavigationLink {
                    YapConversationDetailsView(
                        channel: controller.channel,
                        currentUserID: controller.currentUserID,
                        overrides: overrides
                    )
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("Conversation details")
            }
        }
        .sheet(item: $editingMessage) { message in
            EditMessageSheet(message: message) { text in
                Task {
                    await controller.edit(messageID: message.id, text: text)
                }
            }
        }
        .task {
            await controller.load()
            if controller.error == nil { controller.connect() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            controller.connect()
        }
        .onDisappear { controller.disconnect() }
    }
    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !stagedAttachmentNames.isEmpty else { return }
        draft = ""
        let replyID = replyMessage?.id
        replyMessage = nil
        stagedAttachmentNames = []
        Task {
            await controller.send(text: text, replyTo: replyID, attachments: [])
        }
    }
}

/// Details for the current conversation, including the hydrated YapKit member
/// profiles used by the header and inbox row.
public struct YapConversationDetailsView: View {
    private let channel: YapChannel
    private let currentUserID: String
    private let overrides: YapUIOverrides?
    @Environment(\.yapUIConfiguration) private var appConfiguration

    public init(
        channel: YapChannel,
        currentUserID: String,
        overrides: YapUIOverrides? = nil
    ) {
        self.channel = channel
        self.currentUserID = currentUserID
        self.overrides = overrides
    }

    public var body: some View {
        let configuration = appConfiguration.resolving(overrides)
        let theme = configuration.theme
        List {
            Section {
                VStack(spacing: 12) {
                    YapAvatarStack(
                        users: channel.members.map(\.user),
                        accent: theme.accent
                    )
                    .scaleEffect(1.55)
                    .padding(.vertical, 12)
                    Text(title).font(.title2.weight(.semibold))
                    Text(channel.kind == .group
                         ? "\(channel.members.count) members"
                         : "Direct conversation")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            Section(channel.kind == .group ? "Members" : "Participant") {
                ForEach(channel.members) { member in
                    HStack(spacing: 12) {
                        AsyncImage(url: member.user.avatarURL) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                ZStack {
                                    Circle().fill(theme.accent.opacity(0.16))
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(theme.accent)
                                }
                            }
                        }
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.user.displayName ?? "Unnamed member")
                                .font(.body.weight(.medium))
                            if member.user.id.lowercased() == currentUserID.lowercased() {
                                Text("You")
                                    .font(.caption)
                                    .foregroundStyle(theme.secondaryText)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(theme.canvas)
        .navigationTitle("Details")
#if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private var title: String {
        if channel.kind == .group { return channel.name ?? "Group conversation" }
        return channel.members.first {
            $0.user.id.lowercased() != currentUserID.lowercased()
        }?.user.displayName ?? "Conversation"
    }
}

extension YapConversationView where HeaderAccessory == EmptyView {
    public init(
        controller: YapChannelController,
        overrides: YapUIOverrides? = nil
    ) {
        self.init(controller: controller, overrides: overrides) { EmptyView() }
    }
}

/// The standard toolbar content for a conversation. Replace it with a
/// `YapConversationHeaderRenderer` when the host needs different identity UI.
public struct YapDefaultConversationHeaderRenderer:
    YapConversationHeaderRenderer
{
    public init() {}

    public func makeBody(context: YapConversationHeaderContext) -> some View {
        YapConversationHeader(
            channel: context.channel,
            currentUserID: context.currentUserID,
            theme: context.theme
        )
    }
}

/// The standard channel row used by both inbox entry points.
public struct YapDefaultChannelRowRenderer: YapChannelRowRenderer {
    public init() {}

    public func makeBody(context: YapChannelRowRendererContext) -> some View {
        YapChannelRow(channel: context.channel, theme: context.theme)
    }
}

/// The standard loading, empty, and error treatment for an inbox.
public struct YapDefaultInboxStateRenderer: YapInboxStateRenderer {
    public init() {}

    public func makeBody(context: YapInboxStateRendererContext) -> some View {
        Group {
            switch context.state {
            case .loading:
                YapListSkeleton()
            case .empty:
                ContentUnavailableView(
                    "No conversations yet",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Start a conversation to see it here.")
                )
            case .error(let description):
                ContentUnavailableView {
                    Label(
                        "Couldn’t load conversations",
                        systemImage: "exclamationmark.triangle"
                    )
                } description: {
                    Text(description)
                } actions: {
                    Button("Try again", action: context.retry)
                        .foregroundStyle(context.theme.accent)
                }
            }
        }
    }
}

/// The default visual treatment for realtime typing state.
public struct YapDefaultTypingIndicatorRenderer: YapTypingIndicatorRenderer {
    public init() {}

    public func makeBody(context: YapTypingIndicatorRendererContext)
        -> some View
    {
        TypingIndicator(theme: context.theme)
    }
}

/// The standard message renderer retains all controller actions, including
/// optimistic-send retry, without asking hosts to reproduce chat behavior.
public struct YapDefaultMessageRenderer: YapMessageRenderer {
    public init() {}

    public func makeBody(context: YapMessageRendererContext) -> some View {
        YapMessageRow(
            message: context.message,
            isCurrentUser: context.isCurrentUser,
            previous: context.previousMessage,
            theme: context.theme,
            onReply: context.reply,
            onReact: context.react,
            onEdit: context.edit,
            onDelete: context.delete,
            onRetry: context.retry
        )
    }
}

/// The standard composer. Hosts can replace it to add their own actions while
/// retaining the `YapChannelController` supplied send closure.
public struct YapDefaultComposerRenderer: YapComposerRenderer {
    public init() {}

    public func makeBody(context: YapComposerRendererContext) -> some View {
        YapComposer(
            draft: context.draft,
            replyMessage: context.replyMessage,
            stagedAttachmentNames: context.stagedAttachmentNames,
            isShowingAttachments: context.isShowingAttachments,
            theme: context.theme,
            onSend: context.send
        )
    }
}

private struct YapConversationHeader: View {
    let channel: YapChannel
    let currentUserID: String
    let theme: YapTheme
    var title: String {
        if channel.kind == .group {
            return channel.name ?? "Group conversation"
        }
        return channel.members.first(where: {
            $0.user.id.lowercased() != currentUserID.lowercased()
        })?
            .user.displayName ?? "Conversation"
    }
    var subtitle: String {
        channel.kind == .group
            ? "\(channel.members.count) members" : "Available now"
    }
    private var toolbarUsers: [YapUser] {
        guard channel.kind == .direct else { return channel.members.map(\.user) }
        return channel.members.filter {
            $0.user.id.lowercased() != currentUserID.lowercased()
        }.map(\.user)
    }
    var body: some View {
        HStack(spacing: 9) {
            YapAvatarStack(
                users: toolbarUsers,
                accent: theme.accent
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(
                    theme.secondaryText
                )
            }
        }
    }
}
private struct YapAvatarStack: View {
    let users: [YapUser]
    let accent: Color
    var body: some View {
        HStack(spacing: -7) {
            ForEach(Array(users.prefix(3))) { user in
                AsyncImage(url: user.avatarURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(accent.opacity(0.16))
                }.frame(width: 28, height: 28).clipShape(Circle()).overlay(
                    Circle().stroke(Color.white.opacity(0.9), lineWidth: 2)
                )
            }
        }
    }
}
private struct YapChannelRow: View {
    let channel: YapChannel
    let theme: YapTheme
    var body: some View {
        HStack(spacing: 12) {
            YapAvatarStack(
                users: channel.members.map(\.user),
                accent: theme.accent
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    channel.name
                        ?? (channel.kind == .group
                            ? "Group conversation" : "Conversation")
                ).font(
                    theme.typography.channelTitle.weight(
                        channel.unreadCount > 0 ? .semibold : .regular
                    )
                )
                Text(channel.latestMessageText ?? "No messages yet").font(
                    theme.typography.channelPreview
                ).foregroundStyle(theme.secondaryText).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                if let date = channel.latestMessageAt {
                    Text(date, style: .time).font(.caption).foregroundStyle(
                        theme.secondaryText
                    )
                }
                if channel.unreadCount > 0 {
                    Text("\(channel.unreadCount)").font(.caption2.bold())
                        .foregroundStyle(.white).padding(.horizontal, 7)
                        .padding(.vertical, 4).background(
                            theme.accent,
                            in: Capsule()
                        )
                }
            }
        }.padding(.vertical, theme.metrics.listRowVerticalPadding)
    }
}
private struct YapListSkeleton: View {
    var body: some View {
        VStack(spacing: 14) {
            ForEach(0..<5, id: \.self) { _ in
                HStack(spacing: 12) {
                    Circle().fill(.secondary.opacity(0.12)).frame(
                        width: 44,
                        height: 44
                    )
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4).fill(
                            .secondary.opacity(0.12)
                        ).frame(width: 160, height: 12)
                        RoundedRectangle(cornerRadius: 4).fill(
                            .secondary.opacity(0.08)
                        ).frame(width: 230, height: 10)
                    }
                }
            }.redacted(reason: .placeholder)
        }.padding()
    }
}
private struct TypingIndicator: View {
    let theme: YapTheme
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(theme.accent.opacity(0.7)).frame(
                        width: 6,
                        height: 6
                    )
                }
            }.padding(.horizontal, 14).padding(.vertical, 10).background(
                theme.incomingBubble,
                in: Capsule()
            )
            Text("Typing…").font(.caption).foregroundStyle(theme.secondaryText)
        }.padding(.horizontal).padding(.top, 8)
    }
}

private struct YapMessageRow: View {
    let message: YapMessage
    let isCurrentUser: Bool
    let previous: YapMessage?
    let theme: YapTheme
    let onReply: () -> Void
    let onReact: (String) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onRetry: () -> Void

    private var consecutive: Bool {
        previous?.userId == message.userId
            && message.createdAt.timeIntervalSince(
                previous?.createdAt ?? .distantPast
            ) < 300
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser {
                Spacer(minLength: 40)
            } else if consecutive {
                Color.clear.frame(width: 30)
            } else {
                Circle().fill(theme.accent.opacity(0.15)).frame(
                    width: 30,
                    height: 30
                )
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 3)
            {
                if !isCurrentUser && !consecutive {
                    Text("User \(message.userId.prefix(6))").font(.caption)
                        .foregroundStyle(theme.accent)
                }
                if let reply = message.replyTo {
                    HStack(spacing: 6) {
                        Rectangle().fill(theme.accent).frame(width: 3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Replying to a message").font(.caption.bold())
                                .foregroundStyle(theme.accent)
                            Text(reply.text).font(.caption).lineLimit(1)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                    .padding(8).background(
                        theme.accent.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                }
                ForEach(message.attachments) { attachment in
                    AttachmentPreview(attachment: attachment, theme: theme)
                }
                if message.isDeleted {
                    Text("Message deleted").italic().foregroundStyle(
                        theme.secondaryText
                    )
                } else if !message.text.isEmpty {
                    Text(message.text).font(theme.typography.message)
                        .foregroundStyle(theme.primaryText).padding(
                            .horizontal,
                            theme.metrics.messageHorizontalPadding
                        ).padding(
                            .vertical,
                            theme.metrics.messageVerticalPadding
                        )
                        .background(
                            isCurrentUser
                                ? theme.outgoingBubble : theme.incomingBubble,
                            in: RoundedRectangle(
                                cornerRadius: theme.bubbleCornerRadius,
                                style: .continuous
                            )
                        )
                        .contextMenu {
                            Button(
                                "Reply",
                                systemImage: "arrowshape.turn.up.left",
                                action: onReply
                            )
                            Button("Like", systemImage: "hand.thumbsup") {
                                onReact("👍")
                            }
                            Button("Love", systemImage: "heart") {
                                onReact("❤️")
                            }
                            if isCurrentUser {
                                Button(
                                    "Edit",
                                    systemImage: "pencil",
                                    action: onEdit
                                )
                                Button(
                                    "Delete",
                                    systemImage: "trash",
                                    role: .destructive,
                                    action: onDelete
                                )
                            }
                        }
                }
                HStack(spacing: 5) {
                    Text(message.createdAt, style: .time)
                    if message.editedAt != nil { Text("edited") }
                    if isCurrentUser {
                        Image(
                            systemName: message.readReceipts.isEmpty
                                ? "checkmark" : "checkmark.double"
                        ).foregroundStyle(theme.accent)
                    }
                }.font(.caption2).foregroundStyle(theme.secondaryText)
                if message.deliveryState == .failed {
                    Button(
                        "Retry",
                        systemImage: "arrow.clockwise",
                        action: onRetry
                    )
                    .font(theme.typography.metadata.weight(.semibold))
                    .foregroundStyle(theme.accent)
                }
                if !message.reactions.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(message.reactions, id: \.emoji) { reaction in
                            Button {
                                onReact(reaction.emoji)
                            } label: {
                                Text("\(reaction.emoji) \(reaction.count)")
                                    .font(.caption2).padding(.horizontal, 7)
                                    .padding(.vertical, 4).background(
                                        theme.reactionSurface,
                                        in: Capsule()
                                    ).overlay(
                                        Capsule().stroke(
                                            theme.separator.opacity(
                                                theme.components
                                                    .reactionBorderOpacity
                                            )
                                        )
                                    )
                            }
                        }
                    }
                }
            }
            if !isCurrentUser { Spacer(minLength: 40) }
        }
        .padding(.horizontal).padding(.vertical, consecutive ? 2 : 6)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onReply) {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }.tint(theme.accent)
        }
    }
}
private struct AttachmentPreview: View {
    let attachment: YapAttachment
    let theme: YapTheme
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: attachment.kind == .image ? "photo" : "doc").font(
                .title3
            ).foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(attachment.fileName).font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(
                    ByteCountFormatter.string(
                        fromByteCount: Int64(attachment.byteCount),
                        countStyle: .file
                    )
                ).font(.caption).foregroundStyle(theme.secondaryText)
            }
            Spacer()
            Image(systemName: "arrow.down.circle").foregroundStyle(theme.accent)
        }
        .padding(12)
        .background(
            theme.incomingBubble,
            in: RoundedRectangle(cornerRadius: 14)
        )
    }
}
private struct SearchResultsView: View {
    let results: [YapSearchResult]
    let onSelect: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search results").font(.caption.bold()).foregroundStyle(
                .secondary
            )
            ForEach(results.prefix(5)) { result in
                Button {
                    onSelect(result.message.id)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.message.text).lineLimit(2)
                        Text(result.message.createdAt, style: .date).font(
                            .caption
                        ).foregroundStyle(.secondary)
                    }
                }.buttonStyle(.plain)
            }
        }.padding().background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 14)
        ).padding(.horizontal).padding(.bottom, 8)
    }
}

private struct YapComposer: View {
    @Binding var draft: String
    @Binding var replyMessage: YapMessage?
    @Binding var stagedAttachmentNames: [String]
    @Binding var isShowingAttachments: Bool
    let theme: YapTheme
    let onSend: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            if let replyMessage {
                HStack {
                    Rectangle().fill(theme.accent).frame(width: 3)
                    VStack(alignment: .leading) {
                        Text("Replying").font(.caption.bold()).foregroundStyle(
                            theme.accent
                        )
                        Text(replyMessage.text).font(.caption).lineLimit(1)
                    }
                    Spacer()
                    Button {
                        self.replyMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(
                            theme.secondaryText
                        )
                    }
                }.padding(.horizontal)
            }
            if !stagedAttachmentNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(stagedAttachmentNames, id: \.self) { name in
                            Label(name, systemImage: "doc").font(.caption)
                                .padding(8).background(
                                    theme.accent.opacity(0.1),
                                    in: Capsule()
                                )
                        }
                    }.padding(.horizontal)
                }
            }
            if isShowingAttachments {
                HStack {
                    Button {
                        stagedAttachmentNames.append("Photo")
                    } label: {
                        Label("Photos", systemImage: "photo")
                    }
                    Button {
                        stagedAttachmentNames.append("File")
                    } label: {
                        Label("Files", systemImage: "doc")
                    }
                }.font(.subheadline).foregroundStyle(theme.accent).padding(
                    .horizontal
                ).transition(.move(edge: .bottom).combined(with: .opacity))
            }
            GlassEffectContainer {
                HStack(alignment: .bottom, spacing: 8) {
                    Button {
                        withAnimation(.snappy) { isShowingAttachments.toggle() }
                    } label: {
                        Image(systemName: isShowingAttachments ? "xmark" : "plus")
                            .font(.title3)
                            .symbolEffect(.rotate, value: isShowingAttachments)
                            .padding(10)
                        //                        .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive())
                    .accessibilityLabel("Attachments")
                    
                    HStack(alignment: .bottom) {
                        TextField("Message", text: $draft,axis: .vertical)
                            .lineLimit(1...5)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        
                        //                    .background(theme.incomingBubble, in: Capsule())
                        //                    .overlay(Capsule().stroke(theme.separator.opacity(0.55)))
                        
                        Button(action: onSend) {
                            Image(systemName: "arrow.up")
                        }
                        .buttonStyle(.glassProminent)
                        .accentColor(
                            draft.trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty &&
                            stagedAttachmentNames.isEmpty ?
                            theme.secondaryText.opacity(0.35) : theme.accent
                        )
                        .disabled(
                            draft.trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty && stagedAttachmentNames.isEmpty
                        )
                        .padding(5)
                    }
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)
            //            .background(.bar)
        }
    }
}
private struct EditMessageSheet: View {
    let message: YapMessage
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    init(message: YapMessage, onSave: @escaping (String) -> Void) {
        self.message = message
        self.onSave = onSave
        _text = State(initialValue: message.text)
    }
    var body: some View {
        NavigationStack {
            TextField("Message", text: $text, axis: .vertical).textFieldStyle(
                .roundedBorder
            ).padding().navigationTitle("Edit message").toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }.disabled(
                        text.trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                    )
                }
            }
        }
    }
}

private struct YapNewConversationView: View {
    let service: any YapChatService
    let tenantID: String
    let onCreated: (YapChannel) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var name = ""
    @State private var users: [YapUser] = []
    @State private var selected: Set<String> = []
    @State private var groupMode = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $groupMode) {
                        Text("Direct").tag(false)
                        Text("Group").tag(true)
                    }.pickerStyle(.segmented)
                }
                if groupMode {
                    Section("Group name") {
                        TextField("Weekend Crew", text: $name)
                    }
                }
                Section("People") {
                    ForEach(users) { user in
                        Button {
                            if groupMode {
                                if selected.contains(user.id) {
                                    selected.remove(user.id)
                                } else {
                                    selected.insert(user.id)
                                }
                            } else {
                                selected = [user.id]
                            }
                        } label: {
                            HStack {
                                Text(user.displayName ?? user.id)
                                Spacer()
                                if selected.contains(user.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
                Section {
                    Button(groupMode ? "Create group" : "Start conversation") {
                        Task {
                            do {
                                let channel =
                                    groupMode
                                    ? try await service.createGroupChannel(
                                        name: name.isEmpty ? "New group" : name,
                                        memberIds: Array(selected)
                                    )
                                    : try await service.createDirectChannel(
                                        otherUserId: selected.first ?? ""
                                    )
                                onCreated(channel)
                            } catch {}
                        }
                    }.disabled(
                        selected.isEmpty || (groupMode && selected.count < 2)
                    )
                }
            }.navigationTitle("New conversation").searchable(
                text: $query,
                prompt: "Search people"
            ).toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }.task(id: query) {
                users =
                    (try? await service.users(tenantId: tenantID, query: query))
                    ?? []
            }
        }
    }
}
