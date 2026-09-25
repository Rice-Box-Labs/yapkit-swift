import SwiftUI
import YapKit

#if canImport(UIKit)
import UIKit
#endif

public struct YapConversationView<HeaderAccessory: View>: View {
    @State private var controller: YapChannelController
    @State private var draft = ""
    @State private var replyMessage: YapMessage?
    @State private var editingMessage: YapMessage?
    @State private var stagedAttachmentNames: [String] = []
    @State private var isShowingAttachments = false
    @Environment(\.yapUIConfiguration) private var appConfiguration
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        let typingUsers = resolvedTypingUsers
        let usersByID = Dictionary(
            uniqueKeysWithValues: controller.channel.members.map {
                ($0.user.id.lowercased(), $0.user)
            }
        )
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
                                    user: usersByID[message.userId.lowercased()],
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
                        Group {
                            if !typingUsers.isEmpty {
                                configuration.typingIndicatorRenderer.makeBody(
                                    context: .init(
                                        userIDs: Set(typingUsers.map(\.id)),
                                        typingUsers: typingUsers,
                                        channelKind: controller.channel.kind,
                                        theme: theme
                                    )
                                )
                                .transition(typingIndicatorTransition)
                            }
                        }
                    }
                    .animation(
                        typingIndicatorAnimation,
                        value: typingUsers.map(\.id)
                    )
                    .padding(.bottom, 12)
                }
                .defaultScrollAnchor(.bottom)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
                .contentShape(Rectangle())
                .onTapGesture(perform: dismissKeyboard)
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
                    Image(systemName: "info")
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
            if phase == .active {
                controller.connect()
            } else {
                controller.updateTyping(isTyping: false)
            }
        }
        .onChange(of: draft) { _, value in
            controller.updateTyping(
                isTyping: !value.trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
            )
        }
        .onDisappear {
            controller.updateTyping(isTyping: false)
            controller.disconnect()
        }
    }
    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !stagedAttachmentNames.isEmpty else { return }
        controller.updateTyping(isTyping: false)
        draft = ""
        let replyID = replyMessage?.id
        replyMessage = nil
        stagedAttachmentNames = []
        Task {
            await controller.send(text: text, replyTo: replyID, attachments: [])
        }
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        #endif
    }

    private var resolvedTypingUsers: [YapUser] {
        let activeIDs = Set(
            controller.typingUserIDs.filter {
                $0.caseInsensitiveCompare(controller.currentUserID)
                    != .orderedSame
            }
        )
        let knownUsers = controller.channel.members.map(\.user).filter {
            activeIDs.contains($0.id)
        }
        let knownIDs = Set(knownUsers.map(\.id))
        let unknownUsers = activeIDs.subtracting(knownIDs).sorted().map {
            YapUser(id: $0)
        }
        return knownUsers + unknownUsers
    }

    private var typingIndicatorTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(
                with: .scale(scale: 0.92, anchor: .leading)
            ),
            removal: .opacity.combined(
                with: .scale(scale: 0.96, anchor: .leading)
            )
        )
    }

    private var typingIndicatorAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.15)
            : .spring(response: 0.42, dampingFraction: 0.82)
    }
}

/// Details for the current conversation, including the hydrated YapKit member
extension YapConversationView where HeaderAccessory == EmptyView {
    public init(
        controller: YapChannelController,
        overrides: YapUIOverrides? = nil
    ) {
        self.init(controller: controller, overrides: overrides) { EmptyView() }
    }
}
