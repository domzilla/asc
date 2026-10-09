---
id: '261009-25RT975'
title: Share rule matching between Blocklist and spec find
author: Dominic Rodemer
created_at: '2026-10-09T19:50:50.290083Z'
status: closed
labels:
- refactoring
---


## Parent

261009-25RJQF5

## What to build

`asc spec find` shows `[BLOCKED …]` labels and blocked attributes per endpoint, but it re-implements the rule matching from `Blocklist.violation` instead of calling it. Any change to matching makes the labels agents rely on drift from what is enforced. `Blocklist` should expose one API (e.g. applicable rules for a method and path) used by both the gate and the lookup.

## Acceptance criteria

- [ ] Spec lookup no longer filters `Blocklist.rules` itself
- [ ] `spec find` output is unchanged for blocked, attribute-blocked and allowed endpoints
- [ ] A test pins the labels for one endpoint of each kind

## Blocked by

- 261009-25RTRHW — Make the write gate safe for every HTTP method
