// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {INonfungiblePositionManager} from '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import {IUniswapV3PoolState} from 'src/interfaces/IUniswapV3PoolState.sol';
import {FluxFarmV2} from 'src/FluxFarmV2.sol';
import {AccessControl} from 'src/utils/AccessControl.sol';


contract FluxFarmRecord is UUPSUpgradeable, AccessControl {
    FluxFarmV2 public deployedFluxFarm;
    address public nonfungiblePositionManager;
    address public uniswapV3Pool;
    uint256 public keeperInterval;

    struct Snapshot {
        uint256 timestamp;
        uint256 investId;
        uint160 sqrtPriceX96;
        int24 tick;
        uint128 poolLiquidity;
        uint256 tokenId;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 token0OraclePrice;
        uint256 token1OraclePrice;
        uint256 nowBalanceToken0;
        uint256 nowBalanceToken1;
    }

    uint256 public snapShotCount;
    mapping(uint256 => Snapshot) public snapshotInfo;

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(DEFAULT_ADMIN_ROLE)
        override
    {}

    function initialize() public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER, msg.sender);
        _grantRole(SAFE_ADMIN, msg.sender);
    }

    function setDeployedFluxFarmAddress(address deployedFluxFarmAddress_) public onlyRole(DEFAULT_ADMIN_ROLE) {
        deployedFluxFarm = FluxFarmV2(deployedFluxFarmAddress_);
    }

    function setUniswapV3Pool(address uniswapV3Pool_) public onlyRole(DEFAULT_ADMIN_ROLE) {
        uniswapV3Pool = uniswapV3Pool_;
    }

    function setNonfungiblePositionManager(address nonfungiblePositionManager_) public onlyRole(DEFAULT_ADMIN_ROLE) {
        nonfungiblePositionManager = nonfungiblePositionManager_;
    }

    function setKeeperInterval(uint256 keeperInterval_) public onlyRole(DEFAULT_ADMIN_ROLE) {
        keeperInterval = keeperInterval_;
    }

    function fluxFarmInfo() public view returns (
        uint256 investId,
        uint160 sqrtPriceX96,
        int24 tick,
        uint128 poolLiquidity,
        uint256 tokenId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 token0OraclePrice,
        uint256 token1OraclePrice,
        uint256 nowBalanceToken0,
        uint256 nowBalanceToken1
    ) {
        // get the latest invest id
        investId = deployedFluxFarm.latestInvestID();

        // get the pool state
        (
            sqrtPriceX96,
            tick,,,,,
        ) = IUniswapV3PoolState(uniswapV3Pool).slot0();

        // get the pool liquidity
        poolLiquidity = IUniswapV3PoolState(uniswapV3Pool).liquidity();

        // get farming id
        (tokenId,,) = deployedFluxFarm.getFarmingInfo();

        // get the position info
        (
            ,,,,,
            tickLower,
            tickUpper,
            liquidity,
            ,,,
        ) = INonfungiblePositionManager(nonfungiblePositionManager).positions(tokenId);

        // get the oracle price
        token0OraclePrice = deployedFluxFarm.getPriceIn1e18(deployedFluxFarm.token0());
        token1OraclePrice = deployedFluxFarm.getPriceIn1e18(deployedFluxFarm.token1());

        // get the now balance
        nowBalanceToken0 = IERC20(deployedFluxFarm.token0()).balanceOf(address(deployedFluxFarm));
        nowBalanceToken1 = IERC20(deployedFluxFarm.token1()).balanceOf(address(deployedFluxFarm));
    }

    function snapshot() public {
        require(keeperInterval > 0, "Keeper interval is not set");
        (
            uint256 investId,
            uint160 sqrtPriceX96,
            int24 tick,
            uint128 poolLiquidity,
            uint256 tokenId,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 token0OraclePrice,
            uint256 token1OraclePrice,
            uint256 nowBalanceToken0,
            uint256 nowBalanceToken1
        ) = fluxFarmInfo();

        snapShotCount++;
        snapshotInfo[snapShotCount] = Snapshot(
            block.timestamp,
            investId,
            sqrtPriceX96,
            tick,
            poolLiquidity,
            tokenId,
            tickLower,
            tickUpper,
            liquidity,
            token0OraclePrice,
            token1OraclePrice,
            nowBalanceToken0,
            nowBalanceToken1
        );
    }
}
