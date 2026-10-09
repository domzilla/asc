---
id: '261009-25RTZ42'
title: Run one spec check at a time in the agent
author: Dominic Rodemer
created_at: '2026-10-09T19:50:50.301053Z'
status: open
labels:
- bug
---



## Parent

261009-25RJQF5

## What to build

The agent handles each connection in its own detached task, and `Spec` is a struct with no serialization. When the 24-hour check is due, parallel write requests each download the spec into the same temp zip in the cache directory. One request's cleanup can delete the zip while another is unzipping it, and the losing request fails with exit 4 and "couldn't check Apple's API spec", which suggests the spec changed when it didn't.

Run at most one check at a time per agent (e.g. an actor holding the in-flight check that concurrent callers await), and give each download its own temp file.

## Acceptance criteria

- [ ] Concurrent writes while a check is due trigger one download
- [ ] Concurrent callers all get the same result of that check
- [ ] Temp download files can't collide
- [ ] A test covers concurrent checks without touching the network

## Blocked by

- 261009-25RTCW3 — Spec lookups parse once and work offline
