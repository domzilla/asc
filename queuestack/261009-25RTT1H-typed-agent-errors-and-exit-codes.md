---
id: '261009-25RTT1H'
title: Typed agent errors and exit codes
author: Dominic Rodemer
created_at: '2026-10-09T19:50:50.257406Z'
status: open
labels:
- refactoring
---



## Parent

261009-25RJQF5

## What to build

The CLI shows the "start one with `asc agent start`" hint by catching `ASCError.agent("no agent running")`, i.e. by matching the message text thrown by the socket code. Rewording that message silently drops the hint. The agent also hard-codes exit codes 6 (invalid request) and 1 (other errors) that `ASCError.exitCode` already owns, and the error-to-response mapping exists in three places.

Add a dedicated "agent not running" error case, and one mapping from any error to an agent response that takes its exit code and message from `ASCError`.

## Acceptance criteria

- [ ] No catch matches an error by its message text
- [ ] No literal exit codes outside `ASCError`
- [ ] One error-to-response mapping, used everywhere
- [ ] Exit codes seen by callers are unchanged

## Blocked by

- None (can start immediately)
