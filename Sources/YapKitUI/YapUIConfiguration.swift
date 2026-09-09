import SwiftUI
import YapKit

public struct YapMessageRendererContext {
    public let message: YapMessage
    public let previousMessage: YapMessage?
    public let nextMessage: YapMessage?
    public let isCurrentUser: Bool
    public let currentUserID: String
    public let theme: YapTheme
    public let reply: () -> Void
    public let react: (String) -> Void
    public let edit: () -> Void
    public let delete: () -> Void
    public let retry: () -> Void
}

@MainActor public protocol YapMessageRenderer {
    associatedtype Content: View
    @ViewBuilder func makeBody(context: YapMessageRendererContext) -> Content
}

@MainActor public struct AnyYapMessageRenderer {
    private let render: @MainActor (YapMessageRendererContext) -> AnyView

    public init<Renderer: YapMessageRenderer>(_ renderer: Renderer) {
        render = { context in AnyView(renderer.makeBody(context: context)) }
    }

    public func makeBody(context: YapMessageRendererContext) -> AnyView {
        render(context)
    }
}

public struct YapConversationHeaderContext {
    public let channel: YapChannel
    public let currentUserID: String
    public let theme: YapTheme
}

@MainActor public protocol YapConversationHeaderRenderer {
    associatedtype Content: View
    @ViewBuilder func makeBody(context: YapConversationHeaderContext) -> Content
}

@MainActor public struct AnyYapConversationHeaderRenderer {
    private let render: @MainActor (YapConversationHeaderContext) -> AnyView

    public init<Renderer: YapConversationHeaderRenderer>(_ renderer: Renderer) {
        render = { context in AnyView(renderer.makeBody(context: context)) }
    }

    public func makeBody(context: YapConversationHeaderContext) -> AnyView {
        render(context)
    }
}

public struct YapComposerRendererContext {
    public let draft: Binding<String>
    public let replyMessage: Binding<YapMessage?>
    public let stagedAttachmentNames: Binding<[String]>
    public let isShowingAttachments: Binding<Bool>
    public let theme: YapTheme
    public let send: () -> Void
}

@MainActor public protocol YapComposerRenderer {
    associatedtype Content: View
    @ViewBuilder func makeBody(context: YapComposerRendererContext) -> Content
}

@MainActor public struct AnyYapComposerRenderer {
    private let render: @MainActor (YapComposerRendererContext) -> AnyView

    public init<Renderer: YapComposerRenderer>(_ renderer: Renderer) {
        render = { context in AnyView(renderer.makeBody(context: context)) }
    }

    public func makeBody(context: YapComposerRendererContext) -> AnyView {
        render(context)
    }
}

public struct YapChannelRowRendererContext {
    public let channel: YapChannel
    public let currentUserID: String?
    public let theme: YapTheme
}

@MainActor public protocol YapChannelRowRenderer {
    associatedtype Content: View
    @ViewBuilder func makeBody(context: YapChannelRowRendererContext) -> Content
}

@MainActor public struct AnyYapChannelRowRenderer {
    private let render: @MainActor (YapChannelRowRendererContext) -> AnyView

    public init<Renderer: YapChannelRowRenderer>(_ renderer: Renderer) {
        render = { context in AnyView(renderer.makeBody(context: context)) }
    }

    public func makeBody(context: YapChannelRowRendererContext) -> AnyView {
        render(context)
    }
}

public enum YapInboxState: Equatable {
    case loading
    case empty
    case error(String)
}

public struct YapInboxStateRendererContext {
    public let state: YapInboxState
    public let theme: YapTheme
    public let retry: () -> Void
}

@MainActor public protocol YapInboxStateRenderer {
    associatedtype Content: View
    @ViewBuilder func makeBody(context: YapInboxStateRendererContext) -> Content
}

@MainActor public struct AnyYapInboxStateRenderer {
    private let render: @MainActor (YapInboxStateRendererContext) -> AnyView

    public init<Renderer: YapInboxStateRenderer>(_ renderer: Renderer) {
        render = { context in AnyView(renderer.makeBody(context: context)) }
    }

    public func makeBody(context: YapInboxStateRendererContext) -> AnyView {
        render(context)
    }
}

public struct YapTypingIndicatorRendererContext {
    public let userIDs: Set<String>
    public let theme: YapTheme
}

@MainActor public protocol YapTypingIndicatorRenderer {
    associatedtype Content: View
    @ViewBuilder func makeBody(context: YapTypingIndicatorRendererContext) -> Content
}

@MainActor public struct AnyYapTypingIndicatorRenderer {
    private let render: @MainActor (YapTypingIndicatorRendererContext) -> AnyView

    public init<Renderer: YapTypingIndicatorRenderer>(_ renderer: Renderer) {
        render = { context in AnyView(renderer.makeBody(context: context)) }
    }

    public func makeBody(context: YapTypingIndicatorRendererContext) -> AnyView {
        render(context)
    }
}

/// Complete presentation configuration for YapKitUI. It has no navigation or
/// authentication dependencies; those remain owned by the host application.
@MainActor public struct YapUIConfiguration: @unchecked Sendable {
    public var theme: YapTheme
    public var messageRenderer: AnyYapMessageRenderer
    public var composerRenderer: AnyYapComposerRenderer
    public var headerRenderer: AnyYapConversationHeaderRenderer
    public var channelRowRenderer: AnyYapChannelRowRenderer
    public var inboxStateRenderer: AnyYapInboxStateRenderer
    public var typingIndicatorRenderer: AnyYapTypingIndicatorRenderer

    public init(
        theme: YapTheme = .init(),
        messageRenderer: AnyYapMessageRenderer = .init(YapDefaultMessageRenderer()),
        composerRenderer: AnyYapComposerRenderer = .init(YapDefaultComposerRenderer()),
        headerRenderer: AnyYapConversationHeaderRenderer = .init(YapDefaultConversationHeaderRenderer()),
        channelRowRenderer: AnyYapChannelRowRenderer = .init(YapDefaultChannelRowRenderer()),
        inboxStateRenderer: AnyYapInboxStateRenderer = .init(YapDefaultInboxStateRenderer()),
        typingIndicatorRenderer: AnyYapTypingIndicatorRenderer = .init(YapDefaultTypingIndicatorRenderer())
    ) {
        self.theme = theme
        self.messageRenderer = messageRenderer
        self.composerRenderer = composerRenderer
        self.headerRenderer = headerRenderer
        self.channelRowRenderer = channelRowRenderer
        self.inboxStateRenderer = inboxStateRenderer
        self.typingIndicatorRenderer = typingIndicatorRenderer
    }

    public func resolving(_ overrides: YapUIOverrides?) -> YapUIConfiguration {
        guard let overrides else { return self }
        var resolved = self
        if let theme = overrides.theme { resolved.theme = theme }
        if let renderer = overrides.messageRenderer { resolved.messageRenderer = renderer }
        if let renderer = overrides.composerRenderer { resolved.composerRenderer = renderer }
        if let renderer = overrides.headerRenderer { resolved.headerRenderer = renderer }
        if let renderer = overrides.channelRowRenderer { resolved.channelRowRenderer = renderer }
        if let renderer = overrides.inboxStateRenderer { resolved.inboxStateRenderer = renderer }
        if let renderer = overrides.typingIndicatorRenderer { resolved.typingIndicatorRenderer = renderer }
        return resolved
    }
}

/// Per-view customizations. Non-nil values take precedence over the app-wide
/// `YapUIConfiguration` registered in the environment.
@MainActor public struct YapUIOverrides {
    public var theme: YapTheme?
    public var messageRenderer: AnyYapMessageRenderer?
    public var composerRenderer: AnyYapComposerRenderer?
    public var headerRenderer: AnyYapConversationHeaderRenderer?
    public var channelRowRenderer: AnyYapChannelRowRenderer?
    public var inboxStateRenderer: AnyYapInboxStateRenderer?
    public var typingIndicatorRenderer: AnyYapTypingIndicatorRenderer?

    public init(
        theme: YapTheme? = nil,
        messageRenderer: AnyYapMessageRenderer? = nil,
        composerRenderer: AnyYapComposerRenderer? = nil,
        headerRenderer: AnyYapConversationHeaderRenderer? = nil,
        channelRowRenderer: AnyYapChannelRowRenderer? = nil,
        inboxStateRenderer: AnyYapInboxStateRenderer? = nil,
        typingIndicatorRenderer: AnyYapTypingIndicatorRenderer? = nil
    ) {
        self.theme = theme
        self.messageRenderer = messageRenderer
        self.composerRenderer = composerRenderer
        self.headerRenderer = headerRenderer
        self.channelRowRenderer = channelRowRenderer
        self.inboxStateRenderer = inboxStateRenderer
        self.typingIndicatorRenderer = typingIndicatorRenderer
    }
}

private struct YapUIConfigurationKey: EnvironmentKey {
    static let defaultValue = MainActor.assumeIsolated { YapUIConfiguration() }
}

public extension EnvironmentValues {
    var yapUIConfiguration: YapUIConfiguration {
        get { self[YapUIConfigurationKey.self] }
        set { self[YapUIConfigurationKey.self] = newValue }
    }
}

public extension View {
    func yapUIConfiguration(_ configuration: YapUIConfiguration) -> some View {
        environment(\.yapUIConfiguration, configuration)
    }
}
