#if canImport(UIKit)
import SwiftUI
import YapKit

/// A host-owned onboarding step for requesting YapKit message notifications.
/// Present this after authentication and before entering the inbox.
public struct YapPushPermissionStep: View {
    private let registration: YapPushRegistration
    private let onFinished: () -> Void
    @State private var isRequesting = false
    @State private var errorMessage: String?

    public init(registration: YapPushRegistration, onFinished: @escaping () -> Void) {
        self.registration = registration
        self.onFinished = onFinished
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Stay in the loop")
                .font(.title.bold())
            Text("Get notified when someone sends you a message.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(isRequesting ? "Setting up…" : "Enable notifications") {
                isRequesting = true
                errorMessage = nil
                Task {
                    do {
                        try await registration.start()
                        await MainActor.run { onFinished() }
                    } catch {
                        await MainActor.run {
                            isRequesting = false
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRequesting)
            Button("Maybe later", action: onFinished)
                .buttonStyle(.borderless)
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
    }
}
#endif
