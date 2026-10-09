# asc

A minimal App Store Connect API client for AI agents. It signs requests with a key held only in memory, and refuses prohibited operations – removing apps from sale, price changes, releases, submissions, deleting users and more – before anything is sent.

## Install

```bash
brew install domzilla/tap/asc
```

Requires the [1Password CLI](https://developer.1password.com/docs/cli/) with the desktop app integration enabled.

## Usage

Store each API key as a 1Password item with the fields `key_id`, `issuer_id`, optionally `vendor_number`, and the key attached as `AuthKey_<key_id>.p8`.

```bash
# Load the key once per session (one 1Password approval); stops after 30 minutes by default
asc agent start --credentials "op://Vault/Item" --ttl 30m

# Requests go through the agent
asc GET "/v1/apps?fields[apps]=name,bundleId" --paginate
asc PATCH /v1/appStoreVersionLocalizations/<id> --body change.json

# Look up endpoints in Apple's API spec
asc spec find customerReviews
asc spec show POST /v1/customerReviewResponses

asc agent stop
```

Run `asc --help` for all options and exit codes.

## Safety

- The key is read from 1Password by the agent and kept only in its memory. It is never written to disk, logged or passed as an argument.
- The blocklist is compiled into the binary and checked before a request is signed. There is no override.
- Writes are only allowed while Apple's published API spec matches the one the blocklist was reviewed against, so new endpoints can't slip through unreviewed.
- No third-party dependencies: only Apple frameworks and system tools.

## License

MIT
