import SwiftUI
import YapKit

/// The standard message renderer retains all controller actions, including
/// optimistic-send retry, without asking hosts to reproduce chat behavior.
public struct YapDefaultMessageRenderer: YapMessageRenderer {
    public init() {}

    public func makeBody(context: YapMessageRendererContext) -> some View {
        YapMessageRow(
            message: context.message,
            user: context.user,
            isCurrentUser: context.isCurrentUser,
            currentUserID: context.currentUserID,
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
struct YapMessageRow: View {
    let message: YapMessage
    let user: YapUser?
    let isCurrentUser: Bool
    let currentUserID: String
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

    private var otherReaders: [YapReadReceipt] {
        message.readReceipts.filter {
            $0.user.id.caseInsensitiveCompare(currentUserID) != .orderedSame
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser {
                Spacer(minLength: 40)
            } else if consecutive {
                Color.clear.frame(width: 30)
            } else {
                YapMessageAvatar(user: user, theme: theme)
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 3)
            {
                if !isCurrentUser && !consecutive {
                    Text(user?.displayName ?? "Unknown").font(.caption)
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
                    if isCurrentUser && !otherReaders.isEmpty {
                        HStack(spacing: -4) {
                            ForEach(otherReaders.prefix(3), id: \.user.id) { receipt in
                                YapReadReceiptAvatar(user: receipt.user, theme: theme)
                            }
                        }
                        .transition(
                            .move(edge: .top)
                                .combined(with: .opacity)
                        )
                        .animation(
                            .easeOut(duration: 0.22),
                            value: otherReaders.map(\.user.id)
                        )
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

struct YapMessageAvatar: View {
    let user: YapUser?
    let theme: YapTheme

    var body: some View {
        YapAvatarImage(user: user, theme: theme, size: 30)
    }
}

struct YapReadReceiptAvatar: View {
    let user: YapUser
    let theme: YapTheme

    var body: some View {
        YapAvatarImage(user: user, theme: theme, size: 18)
            .overlay {
                Circle().stroke(theme.canvas, lineWidth: 1.5)
            }
    }
}

struct YapAvatarImage: View {
    let user: YapUser?
    let theme: YapTheme
    let size: CGFloat

    private var initial: String? {
        user?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            .first.map { String($0).uppercased() }
    }

    var body: some View {
        AsyncImage(url: user?.avatarURL) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Circle().fill(theme.accent.opacity(0.16))
                    if let initial {
                        Text(initial)
                            .font(.system(size: size * 0.42, weight: .semibold))
                            .foregroundStyle(theme.accent)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.42))
                            .foregroundStyle(theme.accent)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

struct AttachmentPreview: View {
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
