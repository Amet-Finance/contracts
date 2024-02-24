# Fixed-Flex On-Chain Bonds Contracts

## Overview

Fixed-Flex is a sophisticated blockchain protocol designed for the issuance and management of on-chain bonds. This
platform offers a suite of smart contracts that facilitate a robust and flexible bond ecosystem on the blockchain.

## Key Components

### Contracts

- **Issuer.sol**: The core contract responsible for issuing new bonds. It handles the creation and overall management of
  bond instances.
- **Vault.sol**: Manages financial aspects, including transaction processing, fee details, and rewards associated with
  the bonds.
- **Bond.sol**: Represents individual bond instances and encapsulates specific bond logic and state.

### Interfaces

- **IBond.sol**: Interface for Bond contract, defining essential interactions.
- **IVault.sol**: Interface for Vault contract, outlining key functionalities.
- **IIssuer.sol**: Interface for Issuer contract, specifying necessary contract interactions.

### Libraries

- **Types.sol**: A library containing shared types and structures used in various contracts.
- **helpers**: Directory of helper libraries to support and extend contract functionalities.

### Tests

- **CustomToken.sol**: A mock token contract for testing interactions with ERC20 tokens in the context of bond
  contracts.

## Installation & Setup

To set up the project locally:

1. Clone the repository.
2. Navigate to the project directory.
3. Install dependencies:
   ```bash
   npm install
4. Compile the contracts:
    ```bash
   npx hardhat compile

## Deployment Steps

Follow these steps to deploy the Fixed-Flex On-Chain Bonds Contracts:

1. Set Chain-Specific URI:
    - In the Bond contract, configure the correct URI for the blockchain network where the contract will be deployed.
      This is crucial for the contract's metadata functionalities.
      Deploy Issuer Contract:

2. Deploy the Issuer contract to the blockchain.
    - This contract is responsible for creating and managing bond instances.
3. Deploy Vault Contract:
    - Deploy the Vault contract, which handles financial transactions, fee details, and bond rewards.
      Configure
4. Issuer with Vault Address:
    - Set the deployed Vault contract's address in the Issuer contract.
      This step links the Is

## Usage

Use Hardhat's deployment scripts to deploy contracts. Each contract (Issuer, Vault, Bond) can be deployed and interacted
with using Hardhat commands and scripts.

## Contributing

Contributions to the Fixed-Flex protocol are welcome. Please adhere to coding standards and include tests for new
functionalities.

## Contact

For more information and queries:

- GitHub: [TheUnconstrainedMind](https://github.com/TheUnconstrainedMind)
- Email: [unconstrained@amet.finance](unconstrained@amet.finance)


