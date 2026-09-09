import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Semantic styling values used by YapKitUI's default renderers.
///
/// The theme deliberately describes UI roles instead of a brand palette, so a
/// host app can use its own appearance without forking the chat views.
public struct YapTheme: Sendable {
    public struct Colors: Sendable {
        public var accent: Color
        public var canvas: Color
        public var primaryText: Color
        public var secondaryText: Color
        public var separator: Color
        public var incomingBubble: Color
        public var outgoingBubble: Color
        public var reactionSurface: Color
        public var composerSurface: Color

        public init(
            accent: Color = .yapAccent,
            canvas: Color = .yapCanvas,
            primaryText: Color = .primary,
            secondaryText: Color = .secondary,
            separator: Color = .yapSeparator,
            incomingBubble: Color = .yapIncomingBubble,
            outgoingBubble: Color = .yapOutgoingBubble,
            reactionSurface: Color = .yapReactionSurface,
            composerSurface: Color = .yapComposerSurface
        ) {
            self.accent = accent
            self.canvas = canvas
            self.primaryText = primaryText
            self.secondaryText = secondaryText
            self.separator = separator
            self.incomingBubble = incomingBubble
            self.outgoingBubble = outgoingBubble
            self.reactionSurface = reactionSurface
            self.composerSurface = composerSurface
        }
    }

    public struct Typography: Sendable {
        public var channelTitle: Font
        public var channelPreview: Font
        public var message: Font
        public var metadata: Font
        public var headerTitle: Font
        public var headerSubtitle: Font

        public init(
            channelTitle: Font = .body,
            channelPreview: Font = .subheadline,
            message: Font = .body,
            metadata: Font = .caption2,
            headerTitle: Font = .headline,
            headerSubtitle: Font = .caption
        ) {
            self.channelTitle = channelTitle
            self.channelPreview = channelPreview
            self.message = message
            self.metadata = metadata
            self.headerTitle = headerTitle
            self.headerSubtitle = headerSubtitle
        }
    }

    public struct Metrics: Sendable {
        public var contentSpacing: CGFloat
        public var listRowVerticalPadding: CGFloat
        public var messageHorizontalPadding: CGFloat
        public var messageVerticalPadding: CGFloat
        public var avatarSize: CGFloat
        public var composerButtonSize: CGFloat

        public init(
            contentSpacing: CGFloat = 8,
            listRowVerticalPadding: CGFloat = 7,
            messageHorizontalPadding: CGFloat = 14,
            messageVerticalPadding: CGFloat = 10,
            avatarSize: CGFloat = 30,
            composerButtonSize: CGFloat = 36
        ) {
            self.contentSpacing = contentSpacing
            self.listRowVerticalPadding = listRowVerticalPadding
            self.messageHorizontalPadding = messageHorizontalPadding
            self.messageVerticalPadding = messageVerticalPadding
            self.avatarSize = avatarSize
            self.composerButtonSize = composerButtonSize
        }
    }

    public struct Shapes: Sendable {
        public var bubbleCornerRadius: CGFloat
        public var cardCornerRadius: CGFloat
        public var avatarCornerRadius: CGFloat

        public init(
            bubbleCornerRadius: CGFloat = 22,
            cardCornerRadius: CGFloat = 14,
            avatarCornerRadius: CGFloat = 999
        ) {
            self.bubbleCornerRadius = bubbleCornerRadius
            self.cardCornerRadius = cardCornerRadius
            self.avatarCornerRadius = avatarCornerRadius
        }
    }

    /// Component-level surface and interaction styling.
    public struct Components: Sendable {
        public var composerBorderOpacity: Double
        public var avatarBorderOpacity: Double
        public var reactionBorderOpacity: Double
        public var outgoingMessageUsesAccent: Bool

        public init(
            composerBorderOpacity: Double = 0.55,
            avatarBorderOpacity: Double = 0.9,
            reactionBorderOpacity: Double = 0.4,
            outgoingMessageUsesAccent: Bool = false
        ) {
            self.composerBorderOpacity = composerBorderOpacity
            self.avatarBorderOpacity = avatarBorderOpacity
            self.reactionBorderOpacity = reactionBorderOpacity
            self.outgoingMessageUsesAccent = outgoingMessageUsesAccent
        }
    }

    public var colors: Colors
    public var typography: Typography
    public var metrics: Metrics
    public var shapes: Shapes
    public var components: Components

    public init(
        colors: Colors = .init(),
        typography: Typography = .init(),
        metrics: Metrics = .init(),
        shapes: Shapes = .init(),
        components: Components = .init()
    ) {
        self.colors = colors
        self.typography = typography
        self.metrics = metrics
        self.shapes = shapes
        self.components = components
    }
}

// These aliases keep default renderers concise while public customization uses
// the grouped semantic tokens above.
extension YapTheme {
    var accent: Color { colors.accent }
    var canvas: Color { colors.canvas }
    var primaryText: Color { colors.primaryText }
    var secondaryText: Color { colors.secondaryText }
    var separator: Color { colors.separator }
    var incomingBubble: Color { colors.incomingBubble }
    var outgoingBubble: Color {
        components.outgoingMessageUsesAccent ? colors.accent : colors.outgoingBubble
    }
    var reactionSurface: Color { colors.reactionSurface }
    var bubbleCornerRadius: CGFloat { shapes.bubbleCornerRadius }
    var contentSpacing: CGFloat { metrics.contentSpacing }
}

public extension Color {
    static var yapAccent: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemTeal)
        #elseif canImport(AppKit)
        Color(nsColor: .systemTeal)
        #else
        .teal
        #endif
    }

    static var yapCanvas: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
        #else
        .clear
        #endif
    }

    static var yapIncomingBubble: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .controlBackgroundColor)
        #else
        .gray.opacity(0.16)
        #endif
    }

    static var yapOutgoingBubble: Color {
        #if canImport(UIKit)
        Color(uiColor: .tertiarySystemFill)
        #elseif canImport(AppKit)
        Color(nsColor: .selectedContentBackgroundColor)
        #else
        .teal.opacity(0.2)
        #endif
    }

    static var yapReactionSurface: Color {
        #if canImport(UIKit)
        Color(uiColor: .tertiarySystemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .controlBackgroundColor)
        #else
        .gray.opacity(0.12)
        #endif
    }

    static var yapComposerSurface: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
        #else
        .clear
        #endif
    }

    static var yapSeparator: Color {
        #if canImport(UIKit)
        Color(uiColor: .separator)
        #elseif canImport(AppKit)
        Color(nsColor: .separatorColor)
        #else
        .gray.opacity(0.28)
        #endif
    }
}
