import SwiftUI
import YapKit

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
