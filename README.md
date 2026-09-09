# YapKit Swift SDK

YapKit is a native Swift package for adding direct and group chat to iOS apps.
It includes a transport and controller layer (`YapKit`) plus an optional
SwiftUI presentation layer (`YapKitUI`). Authentication, navigation, identity,
and app-level theming remain owned by the host app.

## Requirements

- Swift 6.2 or later
- iOS 26 or later
- macOS 14 or later (for macOS development and tests)

## Installation

Add the package in Xcode with the repository URL, or add it to
`Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/Rice-Box-Labs/yapkit-swift.git",
        from: "0.1.0"
    )
]
```

Then depend on one or both products:

```swift
targets: [
    .target(
        name: "YourApp",
        dependencies: ["YapKit", "YapKitUI"]
    )
]
```

## Quick start

Your backend should provide a short-lived user token. Never embed a YapKit
server secret in an iOS target.

```swift
import YapKit
import YapKitUI

let client = YapClient(
    authentication: .serverTokenProvider(authProvider)
)

YapInboxView(service: client, tenantID: tenantID) { channel in
    // Route to your conversation screen.
}
```

For a complete host-owned navigation example, see
[`examples/ios`](../../examples/ios).

## Products

- **YapKit** — models, authentication, HTTP/WebSocket transport, sessions, and
  observable controllers.
- **YapKitUI** — native inbox, conversation, details, push-permission, theme,
  and typed renderer components.

## Development

```sh
swift test
swift build --product YapKit
swift build --product YapKitUI
```

YapKit is currently distributed as a private-beta package. Release tags use
semantic versioning, for example `0.1.0`.
