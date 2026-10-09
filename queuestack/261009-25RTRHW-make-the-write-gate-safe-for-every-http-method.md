---
id: '261009-25RTRHW'
title: Make the write gate safe for every HTTP method
author: Dominic Rodemer
created_at: '2026-10-09T19:50:50.235630Z'
status: open
labels:
- refactoring
---



## Parent

261009-25RJQF5

## What to build

The agent accepts any method in `SpecLookup.methods` but runs the blocklist and spec gate only for methods in `Blocklist.writeMethods`. Two lists in two modules decide this, so a method added to the first and not the second (say PUT) would be signed and sent with no checks. The method is a plain `String` everywhere, upper-cased and validated at each layer.

Introduce an `HTTPMethod` type with an `isWrite` property, used by the agent request, blocklist rules, API client and spec lookup, and gate on "not GET" so an unknown write method fails closed.

## Acceptance criteria

- [ ] One definition of the accepted methods
- [ ] The blocklist and spec gate run for every method except GET
- [ ] Unsupported methods are still rejected with a usage error
- [ ] All blocklist tests still pass

## Blocked by

- None (can start immediately)
