# YapKit

YapKit is a private-beta, multi-tenant chat platform for native iOS and Android apps. The first vertical slice is text-only direct messaging with a Cloudflare Worker API, one Durable Object per channel, D1 directory data, and native Swift/Kotlin SDK surfaces.

## Workspace

- `workers/api`: Hono-ready module Worker, D1 schema, `ChannelRoom` Durable Object, and queue consumer.
- `packages/contracts`: OpenAPI 3.1 contract and shared protocol types.
- `sdks/swift`: `YapKit` transport/controllers and `YapKitUI` SwiftUI views.
- `sdks/android`: native Kotlin `yapkit-core` transport and typed chat models.
- `apps/console`: initial developer-console shell for organizations, apps, environments, and credentials.
- `examples/ios`: deterministic SwiftUI sample.

The API is deliberately usable with native Worker APIs so local contract tests do not require a deployed Cloudflare account. Production wiring still requires D1, a Durable Object migration, a queue, and ES256 signing secrets.

## Local API

```sh
pnpm install
pnpm typecheck
pnpm test
pnpm exec wrangler d1 migrations apply yapkit-directory --local --config workers/api/wrangler.jsonc
pnpm dev:api
```

Wrangler's local server does not apply D1 migrations automatically. Run the migration command once before the first local API session (and again after adding a migration).

Copy `workers/api/.dev.vars.example` to `.dev.vars`, then replace its placeholder with the output of `pnpm local:keys`. Keep `YAPKIT_ALLOW_LEGACY_SERVER_SECRET=true` only in local `.dev.vars` for MVP bootstrap; never set it in a deployed environment. Never put a `yk_sk_*` secret in an iOS target.

With the Worker running, exercise the complete local flow:

```sh
pnpm e2e:local
```

The smoke test provisions two users in one tenant, creates one idempotent direct channel, sends a message while deliberately supplying a conflicting body user ID, reads it as the second user, and confirms a third tenant user cannot read that channel.

## Authenticated chat session

Create and retain a `YapChatSession` when the host app enters an authenticated
session. `start()` resolves the YapKit context, loads the current conversations,
and opens the inbox WebSocket. New direct/group conversations and new-message
previews then refresh the inbox immediately. Call `stop()` when that host
session ends.

```swift
let chatSession = YapChatSession(service: yapClient)

Task {
  await chatSession.start()
}
```

## Apple push registration

YapKit owns the authenticated device-registration API; the host app still owns notification permission, its Push Notifications entitlement, and its app-delegate callback. Ask for permission in a user-visible context, then register with APNs and forward the returned token to YapKit:

```swift
import UserNotifications
import UIKit

func application(
  _ application: UIApplication,
  didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
  Task {
    try await yapClient.registerApplePushDevice(
      token: deviceToken,
      bundleIdentifier: Bundle.main.bundleIdentifier!,
      environment: .production
    )
  }
}
```

The Worker now sends message pushes when APNs provider secrets are configured. Set these as Worker secrets (never in the iOS app): `APNS_TEAM_ID`, `APNS_KEY_ID`, and `APNS_PRIVATE_KEY_JWK` (the JSON JWK for the Apple `.p8` key). The app still owns permission, its Push Notifications entitlement, and token forwarding.

## Android SDK

The initial Kotlin transport is in [`sdks/android`](sdks/android). It uses the
same short-lived user-token contract as the Swift SDK and registers FCM tokens
with `/v1/devices/android`. The Android client owns Firebase configuration,
notification permission, notification channels, and notification-tap routing.

FCM delivery requires `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, and
`FCM_PRIVATE_KEY_JWK` as Worker secrets. The private key must never be placed
in an Android application.

## Local developer console

The activation dashboard reads app and environment state from the local Worker,
persists activation steps in D1, and runs a real environment configuration
check. It can also provision a new app with development and production
environments, display environment-scoped publishable keys, and persist the
server-token or OIDC authentication path. Management endpoints resolve an
organization-scoped member. Local development uses a server-side-only key that
bootstraps the local owner; production requests will use the same contract
through an HttpOnly `yapkit_session` cookie once Better Auth issues sessions.

1. Run `pnpm local:setup` in a fresh checkout, or add a strong
   `YAPKIT_CONSOLE_DEV_KEY` to `workers/api/.dev.vars`.
2. Apply D1 migrations and start the Worker with that same environment value.
3. Copy `apps/console/.env.local.example` to `apps/console/.env.local`, fill in
   the Worker URL and the same local console key, then run `pnpm dev` from
   `apps/console`.

`YAPKIT_CONSOLE_DEV_KEY` is exclusively for local development. Do not set it on
a deployed Worker, and do not put it in a `VITE_*` variable. The Worker already
enforces organization-scoped session access; Google OAuth and invitation flows
remain the next Better Auth slice.

### Usage and plans

Each workspace has a monthly usage period. The initial free plan includes 10,000
messages, 100,000 API requests, 10,000 push deliveries, and 100 active users.
The Worker enforces the message limit at the authenticated write boundary and
the console exposes the current period at Chat → Usage. Apply migration `0021`
before enabling this in a deployed database. Pro and Scale limits are present
in the control-plane contract; payment-provider checkout and automatic upgrades
remain intentionally support-assisted until billing credentials are configured.

To enable the Google sign-in handler, set `YAPKIT_CONSOLE_AUTH_SECRET`,
`GOOGLE_CLIENT_ID`, and `GOOGLE_CLIENT_SECRET` in the Worker environment, then
add the callback URL `YAPKIT_CONSOLE_AUTH_BASE_URL/v1/console/auth/callback/google`
to the Google OAuth client. `YAPKIT_CONSOLE_TRUSTED_ORIGINS` should include the
console origin (for example, `http://127.0.0.1:4173` during local development).

## SwiftUI UI SDK

`YapKitUI` is an iOS/iPadOS 26, SwiftUI-only presentation layer. It owns chat
state rendering and calls the public controllers for send, retry, read, search,
and realtime behavior. Your app continues to own authentication, navigation,
tabs, sheets, and its own identity or directory experience.

Register a `YapUIConfiguration` high in the host's view tree. A view's
`YapUIOverrides` wins over that app-wide configuration, and any unspecified
override continues to use the app-wide value. See [`examples/ios`](examples/ios)
for host-owned navigation and custom renderer examples.

The previous flat `YapTheme` fields have been replaced by semantic nested
tokens (`colors`, `typography`, `metrics`, `shapes`, and `components`). Rather
than subclassing or copying the shipped views, implement one of the typed
renderer protocols and place it in `YapUIConfiguration` or `YapUIOverrides`.
The renderer contexts include the relevant models and controller actions, so a
custom message row can keep reply, reaction, edit, delete, and retry behavior.
