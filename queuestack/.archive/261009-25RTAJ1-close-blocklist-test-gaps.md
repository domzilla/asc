---
id: '261009-25RTAJ1'
title: Close blocklist test gaps
author: Dominic Rodemer
created_at: '2026-10-09T19:50:50.224393Z'
status: closed
labels:
- test
---


## Parent

261009-25RJQF5

## What to build

AGENTS.md requires a test that proves every blocklist rule blocks. Several rules are not proven:

- Five of the seven `blockedTypes` (`appPrices`, `appPriceSchedules`, `inAppPurchasePrices`, `inAppPurchasePriceSchedules`, `appAvailabilities`) have no test; deleting any of them fails nothing.
- The territory and app availability `mustBlock` cases use body types that are in `blockedTypes`, so they still pass if their path rule is removed. They compare with `!= nil`, so the test can't tell which rule fired.
- The Game Center deletes (achievements, leaderboard sets, groups, activities, challenges), the POST side of the Family Sharing rules and POST `nominations` are only covered by `everyRuleBlocks`, which builds each request from the rule's own pattern and so can't catch a misspelled resource name.

## Acceptance criteria

- [ ] One test run per `blockedTypes` entry against a neutral path (e.g. `PATCH /v1/apps/1`), asserting the exact reason
- [ ] Availability cases use a neutral body type or assert the expected reason
- [ ] Real-endpoint `mustBlock` cases from spec 4.5.1 for each rule listed above
- [ ] `everyRuleBlocks` asserts `reason == rule.reason`, not just `!= nil`

## Blocked by

- None (can start immediately)
