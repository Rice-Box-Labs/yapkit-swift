import SwiftUI
import YapKit

#if canImport(UIKit)
import UIKit
#endif

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
