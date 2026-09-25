import SwiftUI
import YapKit

#if canImport(UIKit)
import UIKit
#endif

struct TypingIndicator: View {
    let users: [YapUser]
    let isGroup: Bool
    let theme: YapTheme

    private var statusText: String {
        if !isGroup, let name = users.first?.displayName, !name.isEmpty {
            return "\(name) is typing"
        }
        return users.count == 1
            ? "Someone is typing" : "\(users.count) people are typing"
    }

    var body: some View {
        HStack(spacing: isGroup ? 8 : 9) {
            TypingDots(theme: theme)

            if isGroup {
                TypingAvatarStack(users: users, theme: theme)
            }
        }
        .padding(.leading, isGroup ? 7 : 12)
        .padding(.trailing, 12)
        .padding(.vertical, isGroup ? 7 : 10)
        .background(
            theme.incomingBubble,
            in: RoundedRectangle(
                cornerRadius: theme.bubbleCornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: theme.bubbleCornerRadius,
                style: .continuous
            )
            .stroke(theme.separator.opacity(0.38), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusText)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

struct TypingDots: View {
    let theme: YapTheme

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(theme.accent)
                    .frame(width: 6, height: 6)
                    .opacity(reduceMotion ? 0.75 : (isAnimating ? 1 : 0.4))
                    .offset(
                        y: reduceMotion ? 0 : (isAnimating ? -3 : 3)
                    )
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 0.48)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.14),
                        value: isAnimating
                    )
            }
        }
        .frame(width: 26, height: 16)
        .onAppear { isAnimating = !reduceMotion }
        .onChange(of: reduceMotion) { _, isReduced in
            isAnimating = !isReduced
        }
    }
}

struct TypingAvatarStack: View {
    let users: [YapUser]
    let theme: YapTheme

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var visibleUsers: [YapUser] {
        Array(users.prefix(3))
    }

    private var overflowCount: Int {
        max(users.count - visibleUsers.count, 0)
    }

    private var avatarTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.55)),
                removal: .opacity.combined(with: .scale(scale: 0.72))
            )
    }

    private var presenceAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.15)
            : .spring(response: 0.4, dampingFraction: 0.72)
    }

    var body: some View {
        HStack(spacing: -8) {
            ForEach(visibleUsers) { user in
                TypingAvatar(user: user, theme: theme)
                    .transition(avatarTransition)
            }

            if overflowCount > 0 {
                Text("+\(overflowCount)")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(theme.accent)
                    .frame(width: 30, height: 30)
                    .background(
                        theme.accent.opacity(0.14),
                        in: Circle()
                    )
                    .overlay {
                        Circle().stroke(theme.incomingBubble, lineWidth: 2)
                    }
                    .contentTransition(.numericText())
                    .transition(avatarTransition)
            }
        }
        .animation(presenceAnimation, value: users.map(\.id))
        .animation(presenceAnimation, value: overflowCount)
    }
}

struct TypingAvatar: View {
    let user: YapUser
    let theme: YapTheme

    private var initial: String? {
        user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            .first.map { String($0).uppercased() }
    }

    var body: some View {
        AsyncImage(url: user.avatarURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                ZStack {
                    Circle().fill(theme.accent.opacity(0.16))
                    if let initial {
                        Text(initial)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.accent)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                            .foregroundStyle(theme.accent)
                    }
                }
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(Circle())
        .overlay {
            Circle().stroke(theme.incomingBubble, lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }
}

/// The default visual treatment for realtime typing state.
public struct YapDefaultTypingIndicatorRenderer: YapTypingIndicatorRenderer {
    public init() {}

    public func makeBody(context: YapTypingIndicatorRendererContext)
        -> some View
    {
        let users = context.typingUsers.isEmpty
            ? context.userIDs.sorted().map { YapUser(id: $0) }
            : context.typingUsers
        TypingIndicator(
            users: users,
            isGroup: context.channelKind == .group,
            theme: context.theme
        )
    }
}
