# FluxFarm

FluxFarm is a smart contract for automated liquidity management in Uniswap V3 pools. It provides sophisticated features for position management, fee collection, and automated rebalancing.

## Features

- **Automated Position Management**
  - Automatic position rebalancing based on price movements
  - Smart liquidity concentration in optimal price ranges
  - Automated fee harvesting and reinvestment

- **Advanced Price Oracle Integration**
  - Real-time price updates from Chainlink oracles
  - Price-based position management
  - Slippage protection

- **Multiple Position Support**
  - Ability to manage multiple Uniswap V3 positions
  - Position initialization with custom tick ranges
  - Batch position operations

- **Fee Management**
  - Automated fee collection
  - Configurable service fee
  - Fee reinvestment strategy

- **Access Control**
  - Role-based access control
  - Secure admin functions
  - Protected critical operations

## Usage

### Initial Setup

1. Deploy the contract with required parameters:
   ```solidity
   initialize(
       address uniswapV3Pool,
       address positionManager,
       address swapRouterAddress,
       address token0,
       address token1,
       address token0Oracle,
       address token1Oracle
   )
   ```

2. Configure the contract settings:
   ```solidity
   setSlippage(uint256 slippage)
   setserviceFeeFactor(uint256 serviceFeeFactor)
   setUpdateInterval(uint256 updateInterval)
   setReceiver(address receiver)
   ```

### Creating Positions

1. Initialize positions with custom tick ranges:
   ```solidity
   initialPosition(
       int24[][] memory ticks,
       uint256 onePositionValueInToken0
   )
   ```
   This will create multiple positions with specified tick ranges and equal value distribution.

### Managing Investments

1. Deposit tokens:
   ```solidity
   invest(address token, uint256 amount)
   ```

2. Withdraw tokens:
   ```solidity
   withdraw(address token, uint256 amount)
   ```

### Automated Management

The contract automatically manages positions through:

1. Price monitoring and position rebalancing
2. Fee harvesting and reinvestment
3. Chainlink Automation integration for timely updates

Automation trigger:
```solidity
function checkUpkeep(bytes calldata) external view override returns (
    bool upkeepNeeded,
    bytes memory performData
) {
    upkeepNeeded = updateFarmTrigger();
}

function performUpkeep(bytes calldata performData) external override {
    require(updateFarmTrigger(), "No upkeep needed");
    AutoUpdateFarm();
}
```

To manually trigger updates:
```solidity
updateFarm()
```

### Position Monitoring

Monitor your positions through events:
- Track investments and withdrawals
- Monitor fee collection and reinvestment
- Follow position updates and rebalancing

### Emergency Operations

In case of emergency:
1. Close all positions:
   ```solidity
   closeAllPosition(bool isBurn)
   ```

2. Claim stuck tokens:
   ```solidity
   claimTokens(address token, address to, uint256 amount)
   ```

## Security

The contract implements several security measures:

- Role-based access control for sensitive functions
- Slippage protection for all trades
- Secure token transfer handling
- Protected upgrade mechanism (UUPS pattern)

## Note

This contract is designed for automated liquidity management in Uniswap V3 pools. Make sure to thoroughly test and audit before deployment in production environments. 