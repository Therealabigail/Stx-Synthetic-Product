# Synthetic Asset Smart Contract

## Overview
This smart contract implements a synthetic asset system on the Stacks blockchain, allowing users to create, manage, and trade synthetic tokens backed by STX collateral. The contract includes functionality for minting, burning, transferring tokens, and managing collateralized positions with built-in liquidation mechanics.

## Features
- Mint synthetic tokens with STX collateral
- Burn synthetic tokens to reclaim collateral
- Transfer synthetic tokens between addresses
- Collateral management system
- Price oracle integration
- Liquidation mechanism for undercollateralized positions
- Comprehensive error handling
- Safe mathematics implementation

## Key Parameters
- Required Collateral Ratio: 150%
- Liquidation Threshold: 120%
- Minimum Mint Amount: 1.00 tokens (8 decimals)
- Oracle Price Expiry: 15 minutes (900 blocks)
- Maximum Oracle Price: 1,000,000,000,000 (1 trillion)

## Contract Functions

### Public Functions

#### Minting and Burning
1. `mint-synthetic-tokens(mint-amount: uint)`
   - Creates new synthetic tokens backed by STX collateral
   - Requires collateral ratio ≥ 150%
   - Minimum mint amount: 1.00 tokens
   - Returns: (ok true) or appropriate error

2. `burn-synthetic-tokens(burn-amount: uint)`
   - Burns synthetic tokens and returns proportional collateral
   - Must have sufficient token balance
   - Returns: (ok true) or appropriate error

#### Token Operations
1. `transfer-synthetic-tokens(recipient: principal, transfer-amount: uint)`
   - Transfers synthetic tokens between addresses
   - Requires sufficient balance
   - Cannot transfer to self
   - Returns: (ok true) or appropriate error

#### Collateral Management
1. `deposit-additional-collateral(additional-collateral: uint)`
   - Adds more STX collateral to an existing vault
   - Creates new vault if none exists
   - Returns: (ok true) or appropriate error

2. `liquidate-undercollateralized-vault(vault-owner: principal)`
   - Liquidates vaults below 120% collateral ratio
   - Transfers collateral to liquidator
   - Burns corresponding synthetic tokens
   - Returns: (ok true) or appropriate error

#### Oracle Management
1. `update-oracle-price(updated-price: uint)`
   - Updates the oracle price
   - Restricted to contract administrator
   - Returns: (ok true) or appropriate error

### Read-Only Functions

1. `get-token-holder-balance(token-holder: principal)`
   - Returns: Current token balance for the specified address

2. `get-total-token-supply()`
   - Returns: Total supply of synthetic tokens

3. `get-current-asset-price()`
   - Returns: Current oracle price

4. `get-vault-information(vault-owner: principal)`
   - Returns: Vault details including collateral amount, minted tokens, and entry price

5. `calculate-current-collateral-ratio(vault-owner: principal)`
   - Returns: Current collateral ratio for specified vault

## Error Codes
- `ERR-UNAUTHORIZED-ACCESS (u100)`: Unauthorized operation attempt
- `ERR-INSUFFICIENT-TOKEN-BALANCE (u101)`: Insufficient token balance
- `ERR-INVALID-TOKEN-AMOUNT (u102)`: Invalid token amount
- `ERR-ORACLE-PRICE-EXPIRED (u103)`: Oracle price has expired
- `ERR-INSUFFICIENT-COLLATERAL-DEPOSIT (u104)`: Insufficient collateral provided
- `ERR-BELOW-MINIMUM-COLLATERAL-THRESHOLD (u105)`: Below minimum collateral threshold
- `ERR-INVALID-PRICE (u106)`: Invalid price input
- `ERR-ARITHMETIC-OVERFLOW (u107)`: Arithmetic overflow
- `ERR-INVALID-RECIPIENT (u108)`: Invalid recipient address
- `ERR-ZERO-AMOUNT (u109)`: Zero amount not allowed
- `ERR-NO-VAULT-EXISTS (u110)`: Vault does not exist

## Security Features
- Overflow protection in all mathematical operations
- Price oracle expiry checks
- Minimum collateral ratio enforcement
- Administrator-only price updates
- Comprehensive input validation
- Protected transfer mechanics

## Usage Examples

### Minting Synthetic Tokens
```clarity
;; Mint 100 synthetic tokens
(contract-call? .synthetic-asset mint-synthetic-tokens u10000000000)
```

### Transferring Tokens
```clarity
;; Transfer 50 tokens to another address
(contract-call? .synthetic-asset transfer-synthetic-tokens 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM u5000000000)
```

### Adding Collateral
```clarity
;; Add 1000 STX as additional collateral
(contract-call? .synthetic-asset deposit-additional-collateral u1000000000)
```

### Burning Tokens
```clarity
;; Burn 25 tokens to reclaim collateral
(contract-call? .synthetic-asset burn-synthetic-tokens u2500000000)
```

## Best Practices
1. Always check vault collateralization ratio before minting or withdrawing
2. Monitor oracle price updates to ensure fresh pricing
3. Maintain sufficient collateral buffer above liquidation threshold
4. Verify token balances before initiating transfers
5. Be aware of minimum mint amounts when creating new positions

## Implementation Notes
- All amounts use 8 decimal places for precision
- STX transfers are handled automatically by the contract
- Collateral ratios are calculated using the current oracle price
- Liquidations can be triggered by any address
- Price updates must occur at least every 15 minutes

## Security Considerations
1. Never share private keys or contract credentials
2. Monitor vault health regularly to avoid liquidation
3. Verify transaction parameters before submission
4. Be aware of oracle price expiry
5. Maintain adequate collateral buffer for price volatility

## Contract Dependencies
- Requires STX token for collateral
- Relies on administrator for price updates
- Operates on Stacks blockchain