// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUniswapV3PoolState} from 'src/interfaces/IUniswapV3PoolState.sol';

library UniswapV3PositionHelper {
    struct TickData {
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
    }

    function getPositionFees(
        address pool,
        int24 currentTick,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    ) external view returns (uint256 fees0, uint256 fees1) {
        IUniswapV3PoolState uniswapPool = IUniswapV3PoolState(pool);

        if (liquidity == 0) {
            return (tokensOwed0, tokensOwed1);
        }

        // Fetch global fee growth
        uint256 feeGrowthGlobal0X128 = uniswapPool.feeGrowthGlobal0X128();
        uint256 feeGrowthGlobal1X128 = uniswapPool.feeGrowthGlobal1X128();

        // Fetch tick data
        TickData memory tickLowerData = _getTickData(uniswapPool, tickLower);
        TickData memory tickUpperData = _getTickData(uniswapPool, tickUpper);

        // Calculate fee growth inside
        uint256 feeGrowthInside0X128 = _calculateFeeGrowthInside(
            feeGrowthGlobal0X128,
            tickLowerData.feeGrowthOutside0X128,
            tickUpperData.feeGrowthOutside0X128,
            currentTick,
            tickLower,
            tickUpper
        );

        uint256 feeGrowthInside1X128 = _calculateFeeGrowthInside(
            feeGrowthGlobal1X128,
            tickLowerData.feeGrowthOutside1X128,
            tickUpperData.feeGrowthOutside1X128,
            currentTick,
            tickLower,
            tickUpper
        );

        // Calculate fees accrued
        fees0 = tokensOwed0 + _calculateFeesAccrued(feeGrowthInside0X128, feeGrowthInside0LastX128, liquidity);
        fees1 = tokensOwed1 + _calculateFeesAccrued(feeGrowthInside1X128, feeGrowthInside1LastX128, liquidity);
    }

    function _getTickData(IUniswapV3PoolState pool, int24 tick) internal view returns (TickData memory tickData) {
        (, , uint256 feeGrowthOutside0X128, uint256 feeGrowthOutside1X128, , , , ) = pool.ticks(tick);
        
        tickData = TickData({
            feeGrowthOutside0X128: feeGrowthOutside0X128,
            feeGrowthOutside1X128: feeGrowthOutside1X128
        });
    }

    function _calculateFeeGrowthInside(
        uint256 feeGrowthGlobalX128,
        uint256 feeGrowthOutsideLowerX128,
        uint256 feeGrowthOutsideUpperX128,
        int24 currentTick,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (uint256) {
        if (currentTick < tickLower) {
            return feeGrowthOutsideLowerX128 - feeGrowthOutsideUpperX128;
        } else if (currentTick >= tickUpper) {
            return feeGrowthOutsideUpperX128 - feeGrowthOutsideLowerX128;
        } else {
            return feeGrowthGlobalX128 - feeGrowthOutsideLowerX128 - feeGrowthOutsideUpperX128;
        }
    }

    function _calculateFeesAccrued(
        uint256 feeGrowthInsideX128,
        uint256 feeGrowthInsideLastX128,
        uint128 liquidity
    ) internal pure returns (uint256) {
        uint256 feeGrowthDelta = feeGrowthInsideX128 - feeGrowthInsideLastX128;
        return (uint256(liquidity) * feeGrowthDelta) / (1 << 128);
    }
}