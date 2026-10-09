# asc - AGENTS.md

## Project Overview
`asc` is a minimal command-line client for the App Store Connect API, built for AI agents. It signs requests, handles pagination, rate limits and report downloads, and refuses blocked operations. The ASC account runs the whole business, so the guardrails in this file come before everything else.

## Tech Stack
- **Language**: Swift
- **Type**: Swift Package (executable)
- **Platforms**: macOS

## Guides (MANDATORY)
Read `~/Agents/Guides/xcode-project-guide.md` in full before planning or editing anything.

Read these in full before touching the matching code:
- Swift style (`.swift`): `~/Agents/Style/swift-swiftui-style-guide.md`

## Dependencies
None. Use only Apple frameworks (Foundation, CryptoKit) and system tools (`/usr/bin/gunzip`, 1Password `op`). Never add third-party packages: a compromised dependency could take over the ASC account.

## Security Rules (MANDATORY)
- **Keys**: `asc agent start` reads the private key, Key ID and Issuer ID with `op read` and hands them to the background agent through a pipe. Only the agent holds them, in memory, until its TTL ends or `asc agent stop`. Never write keys to disk, print them, log them or pass them as command-line arguments or environment variables.
- **Blocklist**: `Blocklist.swift` is compiled into the binary and is checked before a JWT is created. A blocked request must never be signed or sent, and there is no override flag.
- **Blocked operations**:
  - changing availability of apps, in-app purchases and subscriptions (includes removing from sale), ending pre-orders
  - changing prices of apps, in-app purchases and subscriptions
  - revoking or deactivating certificates
  - managing users, roles, visible apps and invitations
  - expiring builds
  - submitting versions, in-app purchases, subscriptions, subscription groups or featuring nominations for review; releasing versions; changing release type, release date or phased release
  - enabling Family Sharing (irreversible)
  - alternative distribution and marketplace settings
  - deleting App Store versions, in-app purchases, subscriptions, subscription groups, custom product pages, in-app events, A/B tests, Xcode Cloud products and workflows, webhooks, license agreements, App Clip experiences and Game Center objects (the objects themselves; editing their relationships stays allowed)
- **Allowed on purpose** (the user decided; don't block them): offers and offer codes, bundle IDs, capabilities, profiles, merchant and pass type IDs, TestFlight beta review submissions, starting A/B tests, Game Center releases, analytics report request deletion.
- **Blocklist tests**: Every blocklist rule needs a test that proves it blocks. Never remove or loosen a rule without explicit user instruction.
- **New endpoints**: Apple adds endpoints with spec updates, and a blocklist allows them until reviewed. That is why writes are pinned to the reviewed spec (see API Spec).

## API Spec
- `asc` downloads Apple's OpenAPI spec from `https://developer.apple.com/sample-code/app-store-connect/app-store-connect-openapi-specification.zip` and caches it in `~/Library/Caches/asc/`, checking for a newer version at most once per 24h.
- The reviewed spec version and the SHA-256 of `openapi.oas.json` are compile-time constants. Writes are allowed only if the current spec matches both. Reads always work.
- A newer or changed spec, or a failed check, blocks writes (fail closed) until the user reviews the new write endpoints against the blocklist and the constants are bumped.
- Never bump the constants without explicit user instruction.

## Configuration
- No environment-variable configuration or defaults. Everything, including the 1Password key references (`op://…`), is passed as arguments.

## Build Commands
Build output goes to `--scratch-path`, outside the repo, instead of the default `.build` folder.
```bash
# Build
swift build --scratch-path /tmp/asc-build

# Clean
swift package clean --scratch-path /tmp/asc-build
```

## Testing (MANDATORY)
`swift test --scratch-path /tmp/asc-build`

Tests must never call the live API.
