---
id: '261009-25RTNBG'
title: Remove duplicated literals and tool-result checks
author: Dominic Rodemer
created_at: '2026-10-09T19:50:50.322263Z'
status: open
labels:
- refactoring
---



## Parent

261009-25RJQF5

## What to build

Values and checks are copied instead of shared:

- The "did the system tool succeed" check (status, timeout, stderr decoding) is repeated for gunzip, unzip and `op`. Add one helper on the process result.
- Agent startup waits 100 × 100 ms while the error text hard-codes "10 seconds". Use named timeout and interval constants and build the message from them.
- The help text hard-codes the default TTL and the exit-code table.
- The `op://Vault/Item` placeholder is repeated.
- Comments in the blocklist and its tests hard-code spec version "4.5.1", which goes stale on the next bump. Refer to the reviewed-version constant instead.
- The spec and last-check file names are repeated in production code and tests.

## Acceptance criteria

- [ ] One tool-success helper used by all three callers
- [ ] Startup timeout and help-text values come from constants
- [ ] No hard-coded spec version outside the reviewed-version constant
- [ ] Tests pass

## Blocked by

- 261009-25RTT1H — Typed agent errors and exit codes
