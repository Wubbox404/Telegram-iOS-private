# Telegram iOS Local Demo Mode

This patch adds an explicitly labelled, fully local demonstration mode to the
official Telegram iOS client source. It does not authenticate against Telegram,
does not create a Telegram account, and does not send demo data to Telegram.

## Demo credentials

- Phone: `+1 111 111 111`
- Code: `000000`

The regular Telegram authorization path remains unchanged for every other phone
number.

## Included demo features

- Native iOS 26 navigation and Liquid Glass controls.
- Contacts, calls, chat list, chat screens, profiles, settings and Telegram
  Stars history.
- Local chat/profile creation and message sending.
- Local stories.
- Editable owner profile and Stars balance.
- Persistent on-device JSON storage.
- Persistent `ДЕМО` watermark.
- Reset and exit actions.

## Build requirements

The upstream `versions.json` is authoritative. At the revision used for this
patch it requires:

- macOS 26
- Xcode 26.2
- Bazel 8.4.2

Follow the upstream `README.md` to create your own API credentials, bundle
identifier and signing configuration. Do not distribute the app under
Telegram's official name or icon. The upstream client is GPL-licensed; comply
with its source-distribution requirements if you distribute a binary.

Sideloadly signs and installs an existing IPA. It does not compile this source.
Build the device archive on a supported Mac or macOS CI runner first.

## GitHub Actions build

The second patch adds `.github/workflows/build-demo-ipa.yml`.

1. Fork `TelegramMessenger/Telegram-iOS`.
2. Apply both numbered patches in order with `git am`.
3. Push the branch to your fork.
4. Open **Actions → Build Demo IPA → Run workflow**.
5. Download the `TelegramDemo-IPA` artifact and install
   `TelegramDemo.ipa` with Sideloadly.

The job uses GitHub's `macos-26` runner, selects Xcode 26.2 and performs the
official `release_arm64` build using Telegram's fake-signing data. Sideloadly
replaces that signature during installation.

The demo number is intercepted before `auth.sendCode`, and the demo code is
validated locally before any request reaches Telegram.
