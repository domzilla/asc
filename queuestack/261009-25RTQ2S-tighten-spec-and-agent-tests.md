---
id: '261009-25RTQ2S'
title: Tighten spec and agent tests
author: Dominic Rodemer
created_at: '2026-10-09T19:50:50.311651Z'
status: open
labels:
- test
---



## Parent

261009-25RJQF5

## What to build

Some spec and agent tests pass for the wrong reason:

- "Writes are refused when the cached spec differs" passes on any spec-gate error, including a download started by mistake. A reviewed-version mismatch (as opposed to a SHA mismatch) is never tested.
- "A forced check fails when the download fails" accepts any error.
- "Connecting without a listener reports that no agent is running" accepts any `ASCError`.
- "The default TTL is 30 minutes" only restates a constant.

## Acceptance criteria

- [ ] The unreviewed-spec test asserts the "spec changed" reason; a second case covers a version mismatch
- [ ] The forced-check test asserts the download failure
- [ ] The no-agent test asserts the dedicated "agent not running" error
- [ ] The default-TTL test is deleted or replaced by one that checks behaviour

## Blocked by

- 261009-25RTCW3 — Spec lookups parse once and work offline
- 261009-25RTT1H — Typed agent errors and exit codes
