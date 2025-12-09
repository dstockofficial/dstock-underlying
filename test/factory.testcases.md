# DStockUnderlyingFactory – Test Cases

Factory tests should leverage Foundry’s `forge-std/Test` with mocked implementations or the actual `DStockUnderlying` logic. Recommended coverage is as follows.

## Initialization
- **initializer can run once**: Calling `initialize` twice reverts with `InvalidInitialization`.
- **grants expected roles**: The `admin` passed in gains `DEFAULT_ADMIN_ROLE`, `DEPLOYER_ROLE`, and `UPGRADER_ROLE`.
- **beacon wiring**: `underlyingBeacon()` points to a beacon owned by the `admin`, initialized with the supplied implementation.

## createUnderlying
- **only DEPLOYER_ROLE**: Unauthorized callers revert when invoking `createUnderlying`.
- **deploys beacon proxy**: Returned address is a proxy pointing to the beacon implementation.
- **initializes proxy**: The proxy’s storage reflects the constructor args (name, symbol, decimals, admin, compliance).
- **emits UnderlyingCreated**: Event fields match inputs.
- **role separation**: Confirm the new instance’s admin has privileges, not the factory.

## upgradeImplementation
- **only UPGRADER_ROLE**: Unauthorized callers revert.
- **updates beacon implementation**: `underlyingBeacon.implementation()` changes to `newImplementation`, emitting `ImplementationUpgraded`.
- **affects existing proxies**: After upgrading, method calls on previously deployed proxies execute the new implementation (e.g., by exposing a version getter).

## Security / Edge Cases
- **zero addresses rejected**: `initialize` and `createUnderlying` revert if critical addresses are zero (implementation, admin).
- **event sequencing**: Ensure repeated upgrades emit distinct events with correct old/new values.
- **constructor disables initializers**: Deploying the factory and skipping `initialize` should leave the contract unusable until explicitly initialized.

