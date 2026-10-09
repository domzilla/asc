---
id: '261009-25RJQF5'
title: 'Fix review findings: blocklist gaps, spec handling, hygiene'
author: Dominic Rodemer
created_at: '2026-10-09T19:50:42.792451Z'
status: open
labels:
- master
---



## Overview

A whole-codebase review (2026-10-09) found two blocklist gaps that let blocked operations through, plus gaps in the blocklist tests, a race and an offline failure in spec handling, and structural and hygiene debt. The end state: every operation AGENTS.md blocks is refused and proven by a real-endpoint test, the write gate can't be skipped by a new method, spec handling is race-free and works offline for reads, and the code follows the Swift style guide.

## Sub-items

Proposed sequence, top to bottom. Check off each sub-item when it is closed.

- [x] 261009-25RT6QX — Block subscription marketSettings changes (blocked by: none)
- [x] 261009-25RT8X6 — Block release type and date on version creation (blocked by: none)
- [x] 261009-25RTAJ1 — Close blocklist test gaps (blocked by: none)
- [x] 261009-25RT5QP — Decide whether agent status may show Key ID and Issuer ID (blocked by: none)
- [x] 261009-25RTRHW — Make the write gate safe for every HTTP method (blocked by: none)
- [x] 261009-25RT975 — Share rule matching between Blocklist and spec find (blocked by: 261009-25RTRHW)
- [x] 261009-25RTCW3 — Spec lookups parse once and work offline (blocked by: none)
- [x] 261009-25RTZ42 — Run one spec check at a time in the agent (blocked by: 261009-25RTCW3)
- [ ] 261009-25RTT1H — Typed agent errors and exit codes (blocked by: none)
- [ ] 261009-25RTQ2S — Tighten spec and agent tests (blocked by: 261009-25RTCW3, 261009-25RTT1H)
- [ ] 261009-25RTZWB — Socket cleanup: umask, shared bind/connect, socket directory ownership (blocked by: none)
- [ ] 261009-25RTNBG — Remove duplicated literals and tool-result checks (blocked by: 261009-25RTT1H)
- [ ] 261009-25RTMBD — Apply the Swift style guide (blocked by: 261009-25RTRHW, 261009-25RT975, 261009-25RTT1H, 261009-25RTZWB, 261009-25RTNBG)
