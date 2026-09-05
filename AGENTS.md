# Agent notes

## Project contract

- Linux workspace: `/home/nanfl/Projects/poetry-ios-app` (authoritative source).
- Mac mirror: `/Users/nanfm/Projects/poetry-ios-app`, reached with SSH host `macmini`.
- Mac builds and signs; the USB-connected Linux host installs, launches, and reads iPhone logs. Do not design the workflow around a simulator or a Mac-connected iPhone.
- Defaults: project/scheme `PoetryApp`, bundle ID `com.nanfl.PoetryApp`, configuration `Debug`.
- The repository may not yet contain `PoetryApp.xcodeproj`; report that prerequisite instead of fabricating build success.

## Change rules

- Treat `.env.ios-device` as local state: keep it ignored and never commit credentials or keychain passwords.
- Keep project-specific values configurable through `.env.ios-device`; avoid reintroducing `MyPrototype` constants.
- Preserve the persistent SSH signing session: remote codesigning depends on the ControlMaster connection unlocked by `scripts/mac-signing-session.sh`.
- Read `README.md` before changing the Linux↔Mac build, signing, USB-device, or Zed-task workflow. Keep operational detail there rather than duplicating it here.

## Completion

- For script/task edits, run `bash -n scripts/*.sh`, `jq empty .zed/tasks.json`, and `git diff --check`.
- Run an actual build only when the Xcode project exists; a complete pipeline test ends with successful IPA installation and launch on the USB-connected iPhone.
