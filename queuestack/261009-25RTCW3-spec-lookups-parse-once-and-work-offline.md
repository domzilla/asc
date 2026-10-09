---
id: '261009-25RTCW3'
title: Spec lookups parse once and work offline
author: Dominic Rodemer
created_at: '2026-10-09T19:50:50.246686Z'
status: open
labels:
- bug
---



## Parent

261009-25RJQF5

## What to build

`spec find` and `spec show` call the full status check, which reads, hashes and parses the ~7 MB spec, throw the result away, then read and parse it again. Once the 24-hour check is due and the network or Apple is unreachable, both lookups fail even though the cached spec is usable. Fail-closed only matters for writes.

Lookups should download only when a check is due or no cache exists, keep working from the cache if that download fails, and parse the spec once.

## Acceptance criteria

- [ ] Lookups parse the spec once per call
- [ ] With a cached spec and a failing download, `spec find`/`spec show` still work
- [ ] Without a cached spec, lookups still report the download error
- [ ] Writes still fail closed when the check fails (existing spec tests pass)

## Blocked by

- None (can start immediately)
