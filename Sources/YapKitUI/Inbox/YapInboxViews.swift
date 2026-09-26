import SwiftUI
import YapKit
import Iconoir

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

import SwiftUI
import YapKit

#if canImport(UIKit)
import UIKit
#endif

struct YapConversationHeader: View {
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
struct YapAvatarStack: View {
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
struct YapChannelRow: View {
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
struct YapListSkeleton: View {
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
