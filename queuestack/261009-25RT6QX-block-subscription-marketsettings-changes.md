---
id: '261009-25RT6QX'
title: Block subscription marketSettings changes
author: Dominic Rodemer
created_at: '2026-10-09T19:50:50.201214Z'
status: open
labels:
- bug
---



## Parent

261009-25RJQF5

## What to build

A subscription's `marketSettings` attribute (the stores that sell it: `APP_STORE`, `APPLE_SCHOOL`, `APPLE_BUSINESS`) is accepted by `PATCH /v1/subscriptions/{id}` in spec 4.5.1. Leaving out `APP_STORE` takes the subscription off sale on the App Store, which AGENTS.md lists as blocked (changing availability). No rule covers it today; the only attribute rule on subscriptions is `familySharable`. `asc` must refuse any POST or PATCH under subscriptions that sets `marketSettings`.

## Acceptance criteria

- [ ] A POST/PATCH under `/v*/subscriptions/**` whose body sets `marketSettings` is blocked with an availability reason
- [ ] A real-endpoint `mustBlock` test covers `PATCH /v1/subscriptions/1` with `marketSettings`
- [ ] Other subscription edits (e.g. `name`) stay allowed
- [ ] Re-check spec 4.5.1 for any other `marketSettings`-style attribute on in-app purchases, apps or plans

## Blocked by

- None (can start immediately)
