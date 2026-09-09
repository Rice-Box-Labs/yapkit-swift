import SwiftUI
import XCTest
@testable import YapKit
@testable import YapKitUI

@MainActor
final class YapUIConfigurationTests: XCTestCase {
    func testPerViewOverridesWinOverAppWideConfiguration() {
        var applicationTheme = YapTheme()
        applicationTheme.metrics.avatarSize = 44
        var localTheme = YapTheme()
        localTheme.metrics.avatarSize = 28

        let resolved = YapUIConfiguration(theme: applicationTheme).resolving(
            YapUIOverrides(theme: localTheme)
        )

        XCTAssertEqual(resolved.theme.metrics.avatarSize, 28)
    }

    func testUnspecifiedOverridesKeepTheAppWideConfiguration() {
        var applicationTheme = YapTheme()
        applicationTheme.metrics.messageHorizontalPadding = 23

        let resolved = YapUIConfiguration(theme: applicationTheme).resolving(
            YapUIOverrides()
        )

        XCTAssertEqual(resolved.theme.metrics.messageHorizontalPadding, 23)
    }

    func testCustomRenderersReceiveTheirContextsAndActions() {
        let probe = RendererProbe()
        let message = YapMessage(
            id: "message-1",
            userId: "member-1",
            text: "Hello",
            sequence: 1,
            createdAt: .now,
            deliveryState: .failed
        )
        let channel = YapChannel(
            id: "channel-1",
            tenantId: "tenant-1",
            name: "Design",
            members: [YapChannelMember(user: YapUser(id: "member-1"))]
        )
        let messageRenderer = AnyYapMessageRenderer(RecordingMessageRenderer(probe: probe))
        let headerRenderer = AnyYapConversationHeaderRenderer(
            RecordingHeaderRenderer(probe: probe)
        )
        let composerRenderer = AnyYapComposerRenderer(RecordingComposerRenderer(probe: probe))
        let stateRenderer = AnyYapInboxStateRenderer(RecordingStateRenderer(probe: probe))

        var retried = false
        _ = messageRenderer.makeBody(
            context: .init(
                message: message,
                previousMessage: nil,
                nextMessage: nil,
                isCurrentUser: true,
                currentUserID: "member-1",
                theme: .init(),
                reply: {},
                react: { _ in },
                edit: {},
                delete: {},
                retry: { retried = true }
            )
        )
        _ = headerRenderer.makeBody(
            context: .init(channel: channel, currentUserID: "member-1", theme: .init())
        )
        var draft = "A draft"
        var reply: YapMessage?
        var attachmentNames: [String] = []
        var showingAttachments = false
        _ = composerRenderer.makeBody(
            context: .init(
                draft: Binding(get: { draft }, set: { draft = $0 }),
                replyMessage: Binding(get: { reply }, set: { reply = $0 }),
                stagedAttachmentNames: Binding(
                    get: { attachmentNames },
                    set: { attachmentNames = $0 }
                ),
                isShowingAttachments: Binding(
                    get: { showingAttachments },
                    set: { showingAttachments = $0 }
                ),
                theme: .init(),
                send: {}
            )
        )
        _ = stateRenderer.makeBody(
            context: .init(state: .error("offline"), theme: .init(), retry: { retried = true })
        )

        XCTAssertEqual(probe.messageID, "message-1")
        XCTAssertTrue(probe.messageIsCurrentUser)
        XCTAssertEqual(probe.headerChannelID, "channel-1")
        XCTAssertEqual(probe.composerDraft, "A draft")
        XCTAssertEqual(probe.state, .error("offline"))
        XCTAssertFalse(retried)
    }
}

@MainActor
private final class RendererProbe {
    var messageID: String?
    var messageIsCurrentUser = false
    var headerChannelID: String?
    var composerDraft: String?
    var state: YapInboxState?
}

@MainActor
private struct RecordingMessageRenderer: YapMessageRenderer {
    let probe: RendererProbe

    func makeBody(context: YapMessageRendererContext) -> some View {
        probe.messageID = context.message.id
        probe.messageIsCurrentUser = context.isCurrentUser
        return Text(context.message.text)
    }
}

@MainActor
private struct RecordingHeaderRenderer: YapConversationHeaderRenderer {
    let probe: RendererProbe

    func makeBody(context: YapConversationHeaderContext) -> some View {
        probe.headerChannelID = context.channel.id
        return Text(context.channel.id)
    }
}

@MainActor
private struct RecordingComposerRenderer: YapComposerRenderer {
    let probe: RendererProbe

    func makeBody(context: YapComposerRendererContext) -> some View {
        probe.composerDraft = context.draft.wrappedValue
        return Text(context.draft.wrappedValue)
    }
}

@MainActor
private struct RecordingStateRenderer: YapInboxStateRenderer {
    let probe: RendererProbe

    func makeBody(context: YapInboxStateRendererContext) -> some View {
        probe.state = context.state
        return Text("state")
    }
}
