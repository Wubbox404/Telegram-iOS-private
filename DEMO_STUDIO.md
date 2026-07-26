# Demo Studio V2

Demo Studio is a local-only presentation layer inside the real Telegram iOS
client. The normal Telegram authorization flow, account, chats and network
features remain untouched.

## Entry points

- Settings → Demo Studio
- Chats → `ДЕМО` in the navigation bar
- Unique Gift → `⋯` → `ДЕМО: Подарил мне`

Every screen keeps a subtle `ДЕМО` disclosure in the lower-right corner. Its
implementation intentionally lives in the clearly named
`DemoStudioWatermarkView.swift` file.

## Local features

- Create a profile manually or clone the public fields visible to the signed-in
  account by `@username`.
- Assign any local username, including one already occupied on Telegram.
- Edit names, phone, country, registration date, bio, contact status, avatar,
  Premium state, Premium emoji/background and profile rating from 0 through 10.
- Add and edit stories, publications, photos and profile gifts.
- Create chats, write from either side, attach photos, keep drafts, unread
  counters, pin, mute, archive and delete local chats.
- Set a local Stars balance and create/edit transaction history, including
  direction, amount, title, peer, date and a custom photo icon.
- Attach an opened unique Telegram gift to the local owner profile and choose
  which local profile appears as the sender.
- Override the visible owner name, username, phone and avatar in the Settings
  header without changing the real account.

## Storage and network boundary

The data model and persistence implementation live in the standalone
`DemoStudioCore` module. It writes account-scoped JSON and media files under
Application Support. Synthetic profiles are never represented as Telegram
`Peer`/Postbox objects, and local messages are never passed to a Telegram send
API.

Cloning a username is read-only. It copies only data that the currently signed
in account can retrieve, then saves an independent local copy.

## Building

Run the separate `Build Demo Studio V2` workflow. It uses the macOS 26 runner
and Xcode 26.2 SDK, imports the repository's fake signing identity, and builds
a device IPA. The old `Build Demo IPA` workflow remains untouched so the V2
migration does not conflict with earlier manual workflow fixes.

The workflow intentionally enforces:

```text
minimum_os_version = "13.0"
```

This does not stop the app from running on iOS 26. It prevents Xcode 26 from
treating APIs first deprecated in iOS 26 as deployment-target errors throughout
the upstream Telegram and Stripe code.

The resulting `TelegramDemoStudioV2.ipa` is unsigned for App Store distribution
and must be signed for the target device by the sideloading tool.
