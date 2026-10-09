---
id: '261009-25RTZWB'
title: 'Socket cleanup: umask, shared bind/connect, socket directory ownership'
author: Dominic Rodemer
created_at: '2026-10-09T19:50:50.268217Z'
status: closed
labels:
- refactoring
---


## Parent

261009-25RJQF5

## What to build

- The socket is created with 0600 by changing the process-wide `umask` around `bind`. `umask` is per process, so it races with parallel tests that create directories. `chmod` the socket right after `bind` instead; its directory is already 0700.
- `listen` and `connect` repeat the same socket setup and pointer-rebinding code.
- The socket lives in the spec cache directory, and its 0700 permissions come from the spec module's directory creation, so a change to spec caching can weaken the socket. Move ownership of that directory and its permissions into one small paths type (or `Agent`).

## Acceptance criteria

- [ ] No `umask` calls; the socket is still 0600 and its directory 0700
- [ ] `listen` and `connect` share one setup helper
- [ ] The agent's socket path and permissions don't depend on `Spec`
- [ ] Agent socket tests pass

## Blocked by

- None (can start immediately)
