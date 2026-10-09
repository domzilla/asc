---
id: '261009-25RT5QP'
title: Decide whether agent status may show Key ID and Issuer ID
author: Dominic Rodemer
created_at: '2026-10-09T19:50:50.278948Z'
status: closed
labels:
- task
---


## Parent

261009-25RJQF5

## What to build

`asc agent status` prints `key_id` and `issuer_id`, so both end up in every agent transcript that checks the status. AGENTS.md names the private key, Key ID and Issuer ID as what the agent holds and says never to print keys; it's unclear whether "keys" covers the two IDs. Decide, then either mask the IDs in the status output or reword AGENTS.md to say only the private key is secret.

## Acceptance criteria

- [x] Dominic decides: mask or document. Decision (2026-10-09): only the private key is secret; Key ID and Issuer ID may be shown. Keep the status output, reword AGENTS.md.
- [ ] Status output and AGENTS.md agree

## Blocked by

- None (can start immediately)
