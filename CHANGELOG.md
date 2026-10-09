# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `asc` sends requests to the App Store Connect API, with pagination, rate-limit retries and decompressed sales and finance reports.
- `asc agent` keeps the API key from 1Password in memory for a limited time, so a session needs one approval instead of one per call.
- A built-in blocklist refuses prohibited operations such as availability and price changes, releases and submissions before anything is sent.
- Writes are disabled when Apple's API spec changes until the new spec has been reviewed.
- `asc spec find` and `asc spec show` look up endpoints in Apple's API spec and show which are blocked.
- `asc --version` prints the installed version.

### Fixed
- The blocklist now refuses changes to which stores sell a subscription, since dropping the App Store takes it off sale.
- The blocklist now refuses creating an App Store version with a release type or release date.
- `asc spec find` and `asc spec show` now work offline from the cached spec when the daily update check fails, and respond faster.
