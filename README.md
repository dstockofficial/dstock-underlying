## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

#### Prerequisites

Set up environment variables in a `.env` file:

```bash
PRIVATE_KEY=your_private_key
ADMIN_ADDRESS=0x...  # Admin address (typically a Safe multisig)
```

#### Deploy Factory and Implementation

Deploy the DStockUnderlying implementation and DStockUnderlyingFactory:

```shell
$ forge script script/DeployFactory.s.sol:DeployFactory \
  --rpc-url <your_rpc_url> \
  --broadcast \
  --verify
```

Required environment variables:
- `PRIVATE_KEY`: Private key of deployer
- `ADMIN_ADDRESS`: Admin address that will receive all Factory roles

#### Deploy All Contracts (One-Step)

Deploy Factory, Implementation, Compliance (optional), and a sample Underlying instance:

```shell
$ DEPLOY_COMPLIANCE=true \
  TOKEN_NAME="My Token" \
  TOKEN_SYMBOL="MTK" \
  forge script script/DeployAll.s.sol:DeployAll \
  --rpc-url <your_rpc_url> \
  --broadcast \
  --verify
```

#### Create New Underlying Instance

Create a new DStockUnderlying instance via the Factory:

```shell
$ TOKEN_NAME="My Token" \
  TOKEN_SYMBOL="MTK" \
  TOKEN_DECIMALS=18 \
  TOKEN_ADMIN=0x... \
  COMPLIANCE_ADDRESS=0x... \
  forge script script/DeployUnderlying.s.sol:DeployUnderlying \
  --rpc-url <your_rpc_url> \
  --broadcast
```

Required environment variables:
- `PRIVATE_KEY`: Private key of deployer (must have DEPLOYER_ROLE)
- `FACTORY_ADDRESS`: Address of deployed DStockUnderlyingFactory
- `TOKEN_NAME`: Token name
- `TOKEN_SYMBOL`: Token symbol
- `TOKEN_ADMIN`: Admin address for the token instance

For more detailed deployment instructions, see [script/README.md](script/README.md).

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
