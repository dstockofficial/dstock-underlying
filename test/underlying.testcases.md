# DStockUnderlying – Test Cases

The following scenarios outline the unit tests that should be implemented for `DStockUnderlying`. Each test should deploy a fresh proxy instance via the factory helper or through a dedicated fixture, ensuring isolation and deterministic expectations.

## Initialization
- **initializes state via proxy once**: Calling `initialize` twice must revert with `Invalid Initialization`.
- **stores metadata overrides**: `name()`, `symbol()`, `decimals()` should equal the values passed to `initialize`.
- **grants admin roles**: The `admin` address receives `DEFAULT_ADMIN_ROLE`, `CONFIGURER_ROLE`, `MINTER_ROLE`, `BURNER_ROLE`, and `PAUSER_ROLE`.
- **optional compliance wiring**: When `compliance_` is non-zero, `compliance()` emits `ComplianceChanged` and stores the address; zero address leaves it unset.

## Admin Configuration
- **setName updates and emits**: Only `CONFIGURER_ROLE` can update the name. Reverts with `ValueUnchanged` if the value is identical.
- **setSymbol updates and emits**: Mirrors `setName` behavior.
- **setCompliance validates change**: Accepts a new compliance address, reverts with `ValueUnchanged` if identical, and blocks calls from non-configurers.

## Minting & Burning
- **mint restricted to MINTER_ROLE**: Non-minters revert; minters increase balances and `totalSupply`.
- **burn restricted to BURNER_ROLE**: Burns reduce balances and supply; reverts when caller lacks role.

## Pausing
- **pause / unpause gated**: Only `PAUSER_ROLE` can pause. While paused, `_update` reverts with `TokenPaused`.
- **transfers allowed when unpaused**: Normal transfer, mint, and burn flows succeed once unpaused.

## Compliance Hook
- **compliance checked on transfers**: With a mocked compliance module, verify `_checkCompliance` is invoked for `from`, `to`, and intermediary `msg.sender` when applicable.
- **bypassed when unset**: No external calls when `compliance` is zero address.

## ERC20 Behavior
- **transfer / approve / transferFrom**: Standard ERC20 semantics hold, including allowance consumption.
- **mint emits Transfer**: Ensure events reflect ERC20 expectations (from `address(0)`).
- **burn emits Transfer**: Ensure events reflect burning to `address(0)`.

