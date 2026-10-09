---
id: '261009-25RT8X6'
title: Block release type and date on version creation
author: Dominic Rodemer
created_at: '2026-10-09T19:50:50.213103Z'
status: open
labels:
- bug
---



## Parent

261009-25RJQF5

## What to build

The blocklist stops `releaseType` and `earliestReleaseDate` only on PATCH of an App Store version. `AppStoreVersionCreateRequest` (`POST /v1/appStoreVersions`) accepts both in spec 4.5.1, so creating a version can set its release type or release date, which AGENTS.md blocks. Creating a version with either attribute must be refused; creating one without them stays allowed.

## Acceptance criteria

- [ ] `POST /v1/appStoreVersions` with `releaseType` or `earliestReleaseDate` is blocked
- [ ] `POST /v1/appStoreVersions` with only `platform` and `versionString` is allowed
- [ ] Real-endpoint `mustBlock` and `mustAllow` tests for both

## Blocked by

- None (can start immediately)
