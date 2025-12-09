# DStockUnderlyingCompliance – Test Cases

Unit tests should instantiate the compliance contract with a mock underlying token and owner. The following cases ensure coverage of whitelist/blacklist flows and caller gating.

## Deployment
- **rejects zero underlying**: Constructor reverts when `_underlyingToken` is zero.
- **rejects zero owner**: Constructor reverts when `_owner` is zero.
- **stores immutable references**: `underlyingToken()` equals the constructor argument; `owner()` equals `_owner`.

## Access Control
- **only owner mutates settings**: `setWhitelistRequired`, `setWhitelist`, and `setBlacklist` revert when called by non-owners.
- **only underlying can check compliance**: Calls to `checkIsCompliant` from any address other than `underlyingToken` revert with `NotUnderlyingCaller`.

## Whitelist Required Flag
- **toggle emits event**: `setWhitelistRequired` updates storage and emits `WhitelistRequiredSet`.
- **default false path**: When `whitelistRequired` is false, accounts not in `blacklisted` pass compliance.

## Whitelist Operations
- **bulk set success**: Batch updates mark each address allowed/disallowed and emit `WhitelistUpdated`.
- **enforcement when required**: With `whitelistRequired = true`, non-whitelisted users trigger `NotCompliant`.

## Blacklist Operations
- **bulk set success**: Batch updates mark addresses blocked and emit `BlacklistUpdated`.
- **blacklist precedence**: Even when whitelisted, a blacklisted user reverts with `NotCompliant`.

## Miscellaneous
- **no-op compliance returns**: When a user passes checks, the function does not revert.
- **gas sanity**: Optional test to ensure loops handle large batches (e.g., 25 entries) without exceeding block gas limits.

