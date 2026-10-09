---
id: '261009-25RTMBD'
title: Apply the Swift style guide
author: Dominic Rodemer
created_at: '2026-10-09T19:50:50.332768Z'
status: open
labels:
- refactoring
---



## Parent

261009-25RJQF5

## What to build

Bring the sources in line with `~/Agents/Style/swift-swiftui-style-guide.md` and `~/Agents/Guides/xcode-project-guide.md`. This touches every file, so it goes last.

- MARK Public/Private sections are missing in Blocklist, JWT, RequestPath, Credentials, the agent's `Server`, and UnixSocket (which has Private but no Public).
- `init` is not first in RequestPath.
- More than one primary type per file: `Server` in the Agent file, `OnePassword` in the Credentials file, `PipeCollector` in the ProcessRunner file.
- Key ID and Issuer ID are plain `String`s; the guide asks for ID wrapper types.
- The `forceCheck` parameter doesn't start with is/has/can/should.
- Six `///` comments restate the code.
- Sources sit directly in `src/asc/` instead of `src/asc/Classes/`.

## Acceptance criteria

- [ ] Every rule above holds across `src/asc`
- [ ] Build and `swift test --scratch-path /tmp/asc-build` pass

## Blocked by

- 261009-25RTRHW — Make the write gate safe for every HTTP method
- 261009-25RT975 — Share rule matching between Blocklist and spec find
- 261009-25RTT1H — Typed agent errors and exit codes
- 261009-25RTZWB — Socket cleanup: umask, shared bind/connect, socket directory ownership
- 261009-25RTNBG — Remove duplicated literals and tool-result checks
