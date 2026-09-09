#if canImport(UIKit)
import UIKit
import UserNotifications

/// Host-app integration for YapKit remote notifications.
///
/// The host still controls when permission is requested and what a tap does.
/// This helper owns the repetitive APNs token forwarding and notification
/// delegate plumbing.
public final class YapPushRegistration: NSObject, UNUserNotificationCenterDelegate {
    public typealias ConversationHandler = @MainActor (_ channelID: String) -> Void

    private let client: YapClient
    private let environment: YapAPNsEnvironment
    private let conversationHandler: ConversationHandler?

    public init(
        client: YapClient,
        environment: YapAPNsEnvironment,
        conversationHandler: ConversationHandler? = nil
    ) {
        self.client = client
        self.environment = environment
        self.conversationHandler = conversationHandler
    }

    /// Requests permission and starts APNs registration. Call after the user
    /// has reached a context where notifications are expected.
    @MainActor
    public func start(requestPermission: Bool = true) async throws {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        if requestPermission {
            _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        }
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Forward the token from the host app delegate. APNs may issue a new
    /// token, so hosts should call this every time the callback runs.
    @MainActor
    public func didRegister(deviceToken: Data) async throws {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            throw YapError.transport("missing bundle identifier")
        }
        try await client.registerApplePushDevice(
            token: deviceToken,
            bundleIdentifier: bundleIdentifier,
            environment: environment
        )
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let payload = response.notification.request.content.userInfo["yapkit"] else { return }
        let channelID: String?
        if let dictionary = payload as? [String: Any] {
            channelID = dictionary["channelId"] as? String
        } else if let dictionary = payload as? [AnyHashable: Any] {
            channelID = dictionary["channelId"] as? String
        } else {
            channelID = nil
        }
        guard let channelID else { return }
        Task { @MainActor [conversationHandler] in
            conversationHandler?(channelID)
        }
    }
}
#endif
