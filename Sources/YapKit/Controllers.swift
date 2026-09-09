import Foundation
import Observation

@MainActor @Observable public final class YapChannelListController {
    public private(set) var channels: [YapChannel] = []; public private(set) var isLoading = false; public private(set) var error: YapError?; public private(set) var connectionState: YapConnectionState = .disconnected
    private let client: any YapChatService; private let tenantId: String
    @ObservationIgnored private var socket: YapInboxSocket?
    @ObservationIgnored private var receiveTask: Task<Void, Never>?
    public init(client: any YapChatService, tenantId: String) { self.client = client; self.tenantId = tenantId }
    public func start() async { await load(); guard error == nil else { connectionState = .failed("inbox_load_failed"); return }; connect() }
    public func retry() async { await start() }
    public func load() async {
        isLoading = channels.isEmpty; error = nil
        do { channels = try await client.channels(tenantId: tenantId) }
        catch let e as YapError { self.error = e }
        catch let underlying { self.error = .transport(underlying.localizedDescription) }
        isLoading = false
    }
    public func connect() { receiveTask?.cancel(); socket?.cancel(); receiveTask = Task { [weak self] in await self?.runRealtimeLoop() } }
    public func disconnect() { receiveTask?.cancel(); receiveTask = nil; socket?.cancel(); socket = nil; connectionState = .disconnected }
    private func runRealtimeLoop() async {
        var backoff: UInt64 = 1_000_000_000
        while !Task.isCancelled {
            connectionState = channels.isEmpty ? .connecting : .reconnecting
            do {
                let connectedSocket = try await client.openInboxSocket()
                socket = connectedSocket; connectionState = .connected; backoff = 1_000_000_000
                while !Task.isCancelled {
                    let event = try await connectedSocket.receive()
                    if case .failure(let code) = event {
                        throw YapError.server(code: code)
                    }
                    await receive(event)
                }
            } catch let failure {
                guard !Task.isCancelled else { break }
                error = (failure as? YapError) ?? .transport(failure.localizedDescription)
                connectionState = .reconnecting
                try? await Task.sleep(nanoseconds: backoff)
                backoff = min(backoff * 2, 30_000_000_000)
            }
        }
    }
    private func receive(_ event: YapInboxSocketEvent) async {
        switch event {
        // Reload after the subscription is accepted so a channel created in
        // the fetch-to-connect window cannot be missed.
        case .ready(let version): inboxVersion = max(inboxVersion, version); await load()
        case .channelsChanged(let version): inboxVersion = max(inboxVersion, version); await load()
        case .failure(let code): error = .server(code: code)
        }
    }
    private var inboxVersion = 0
}

/// Own this alongside the host app's authenticated session. Starting it loads
/// the conversation list once, then keeps it current until the user signs out.
@MainActor @Observable public final class YapChatSession {
    public private(set) var context: YapContext?
    public private(set) var inbox: YapChannelListController?
    public private(set) var error: YapError?
    private let service: any YapChatService
    public init(service: any YapChatService) { self.service = service }
    public func start() async {
        do {
            inbox?.disconnect()
            let context = try await service.currentContext()
            self.context = context
            let inbox = YapChannelListController(client: service, tenantId: context.tenantId)
            self.inbox = inbox
            await inbox.start()
        } catch let error as YapError { self.error = error }
        catch { self.error = .transport(error.localizedDescription) }
    }
    public func stop() { inbox?.disconnect(); inbox = nil; context = nil }
}

@MainActor @Observable public final class YapChannelController {
    public private(set) var messages: [YapMessage] = []; public private(set) var isLoading = false; public private(set) var error: YapError?; public private(set) var connectionState: YapConnectionState = .disconnected; public private(set) var typingUserIDs: Set<String> = []; public private(set) var searchResults: [YapSearchResult] = []
    private let client: any YapChatService; public let channel: YapChannel; public let currentUserID: String; private var lastSequence = 0
    @ObservationIgnored private var socket: YapChannelSocket?
    @ObservationIgnored private var receiveTask: Task<Void, Never>?
    public init(client: any YapChatService, channel: YapChannel, currentUserID: String = "self") { self.client = client; self.channel = channel; self.currentUserID = currentUserID }
    public func load() async { isLoading = true; error = nil; do { merge(try await client.messages(channelId: channel.id, after: lastSequence)); await markReadIfNeeded() } catch let e as YapError { self.error = e; connectionState = .failed(String(describing: e)) } catch let underlying { self.error = .transport(underlying.localizedDescription); connectionState = .failed(underlying.localizedDescription) }; isLoading = false }
    public func retry() async { await load() }
    public func connect() { receiveTask?.cancel(); socket?.cancel(); receiveTask = Task { [weak self] in await self?.runRealtimeLoop() } }
    public func disconnect() { receiveTask?.cancel(); receiveTask = nil; socket?.cancel(); socket = nil; connectionState = .disconnected }
    public func send(text: String, replyTo: String? = nil, attachments: [String] = []) async {
        let clientID = UUID().uuidString
        let localID = "local:\(clientID)"
        let pending = YapMessage(id: localID, userId: currentUserID, text: text, sequence: .max, createdAt: .now, deliveryState: .sending, clientID: clientID, replyTo: replyTo.flatMap { id in messages.first(where: { $0.id == id }).map { YapMessagePreview(id: $0.id, userId: $0.userId, text: $0.text) } }, attachments: [])
        messages.append(pending)
        do {
            resolvePending(localID: localID, with: try await client.sendMessage(channelId: channel.id, text: text, replyTo: replyTo, attachments: attachments, clientId: clientID))
        } catch let failure {
            markPendingFailed(localID: localID, error: failure)
        }
    }
    public func edit(messageID: String, text: String) async { do { replace(try await client.editMessage(channelId: channel.id, messageId: messageID, text: text)) } catch let failure { error = (failure as? YapError) ?? .transport(failure.localizedDescription) } }
    public func delete(messageID: String) async { do { try await client.deleteMessage(channelId: channel.id, messageId: messageID); if let index = messages.firstIndex(where: { $0.id == messageID }) { let old = messages[index]; messages[index] = YapMessage(id: old.id, userId: old.userId, text: "", sequence: old.sequence, createdAt: old.createdAt, replyTo: old.replyTo, attachments: [], reactions: old.reactions, readReceipts: old.readReceipts, editedAt: old.editedAt, isDeleted: true) } } catch let failure { error = (failure as? YapError) ?? .transport(failure.localizedDescription) } }
    public func toggleReaction(messageID: String, emoji: String) async { do { replace(try await client.toggleReaction(channelId: channel.id, messageId: messageID, emoji: emoji)) } catch let failure { error = (failure as? YapError) ?? .transport(failure.localizedDescription) } }
    public func search(query: String) async { guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { searchResults = []; return }; do { searchResults = try await client.searchMessages(channelId: channel.id, query: query) } catch let failure { error = (failure as? YapError) ?? .transport(failure.localizedDescription) } }
    public func clearSearch() { searchResults = [] }
    public func retryFailedMessage(id: String) async {
        guard let message = messages.first(where: { $0.id == id && $0.deliveryState == .failed }) else { return }
        let clientID = UUID().uuidString
        let localID = "local:\(clientID)"
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index] = YapMessage(id: localID, userId: message.userId, text: message.text, sequence: .max, createdAt: .now, deliveryState: .sending, clientID: clientID)
        do {
            resolvePending(localID: localID, with: try await client.sendMessage(channelId: channel.id, text: message.text, clientId: clientID))
        } catch let failure {
            markPendingFailed(localID: localID, error: failure)
        }
    }
    private func runRealtimeLoop() async {
        var backoff: UInt64 = 1_000_000_000
        while !Task.isCancelled {
            connectionState = lastSequence == 0 ? .connecting : .reconnecting
            do {
                try await catchUp()
                let connectedSocket = try await client.openChannelSocket(channelId: channel.id, after: lastSequence)
                socket = connectedSocket; connectionState = .connected; backoff = 1_000_000_000
                while !Task.isCancelled {
                    let event = try await connectedSocket.receive()
                    if case .failure(let code) = event {
                        throw YapError.server(code: code)
                    }
                    await receive(event)
                }
            } catch let failure {
                guard !Task.isCancelled else { break }
                if let yapError = failure as? YapError {
                    error = yapError
                } else {
                    error = .transport(failure.localizedDescription)
                }
                connectionState = .reconnecting
                try? await Task.sleep(nanoseconds: backoff)
                backoff = min(backoff * 2, 30_000_000_000)
            }
        }
    }
    private func catchUp() async throws { merge(try await client.messages(channelId: channel.id, after: lastSequence)); await markReadIfNeeded() }
    private func receive(_ event: YapSocketEvent) async { switch event { case .ready(let sequence): lastSequence = max(lastSequence, sequence); case .messageCreated(let message), .acknowledgement(let message): merge([message]); await markReadIfNeeded(); case .messageUpdated(let message), .reactionUpdated(let message): replace(message); case .read(_, _): break; case .typing(let userID, let isTyping): if isTyping { typingUserIDs.insert(userID) } else { typingUserIDs.remove(userID) }; case .failure(let code): error = .server(code: code) } }
    private func markReadIfNeeded() async { guard lastSequence > 0 else { return }; try? await client.markChannelRead(channelId: channel.id, through: lastSequence) }
    private func resolvePending(localID: String, with message: YapMessage) {
        messages.removeAll { $0.id == localID }
        merge([message])
    }
    private func markPendingFailed(localID: String, error: Error) {
        guard let index = messages.firstIndex(where: { $0.id == localID }) else { return }
        let message = messages[index]
        messages[index] = YapMessage(id: message.id, userId: message.userId, text: message.text, sequence: message.sequence, createdAt: message.createdAt, deliveryState: .failed)
        self.error = (error as? YapError) ?? .transport(error.localizedDescription)
    }
    private func replace(_ message: YapMessage) { if let index = messages.firstIndex(where: { $0.id == message.id }) { messages[index] = message } else { merge([message]) } }
    private func merge(_ incoming: [YapMessage]) {
        for message in incoming {
            if let clientID = message.clientID,
               let pendingIndex = messages.firstIndex(where: { $0.deliveryState == .sending && $0.clientID == clientID }) {
                messages[pendingIndex] = message
            } else if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
            }
        }
        messages.sort { $0.sequence < $1.sequence }
        lastSequence = max(lastSequence, messages.last?.sequence ?? lastSequence)
    }
}
