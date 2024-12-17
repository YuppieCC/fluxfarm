// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";
import {UUPSProxy} from "../src/utils/UUPSProxy.sol";
import {FluxFarmRecord} from 'src/FluxFarmRecord.sol';

contract FluxFarmRecordTest is Test {
    FluxFarmRecord public fluxFarmRecord;

    address public uniswapV3Pool = 0xD1F1baD4c9E6c44DeC1e9bF3B94902205c5Cd6C3;
    address public deployedFluxFarm = 0xfc078b6dA7eb45a858C58cD8f66e3C6d64Cd5C3F;
    address public nonfungiblePositionManager = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    function setUp() public {
        fluxFarmRecord = FluxFarmRecord(
            address(new UUPSProxy(
                address(new FluxFarmRecord()), '')
            )
        );

        fluxFarmRecord.initialize();
        fluxFarmRecord.setDeployedFluxFarmAddress(deployedFluxFarm);
        fluxFarmRecord.setUniswapV3Pool(uniswapV3Pool);
        fluxFarmRecord.setNonfungiblePositionManager(nonfungiblePositionManager);
        fluxFarmRecord.setKeeperInterval(1 hours);
    }

    function test_snapshot() public {
        fluxFarmRecord.snapshot();
        assertTrue(fluxFarmRecord.snapShotCount() > 0);

        (
            uint256 timestamp,
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
        ) = fluxFarmRecord.snapshotInfo(fluxFarmRecord.snapShotCount());

        emit log_named_uint("timestamp: ", timestamp);
        emit log_named_uint("investId: ", investId);
        emit log_named_uint("sqrtPriceX96: ", sqrtPriceX96);
        emit log_named_int("tick: ", tick);
        emit log_named_uint("poolLiquidity: ", poolLiquidity);
        emit log_named_uint("tokenId: ", tokenId);
        emit log_named_int("tickLower: ", tickLower);
        emit log_named_int("tickUpper: ", tickUpper);
        emit log_named_uint("liquidity: ", liquidity);
        emit log_named_uint("token0OraclePrice: ", token0OraclePrice);
        emit log_named_uint("token1OraclePrice: ", token1OraclePrice);
        emit log_named_uint("nowBalanceToken0: ", nowBalanceToken0);
        emit log_named_uint("nowBalanceToken1: ", nowBalanceToken1);
    }
}


