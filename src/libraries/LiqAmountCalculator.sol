// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {TickMath} from '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import {LiquidityAmounts} from '@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol';

library LiqAmountCalculator {

    function getFactor(
        int24 tick_current,
        int24 tick_lower,
        int24 tick_upper,
        uint256 token0_decimals,
        uint256 token1_decimals
    ) external pure returns (uint256 factor) {
        uint256 token0_unit = 10 ** token0_decimals;
        uint256 token1_unit = 10 ** token1_decimals;
        uint160 sqrtPriceX96_current = TickMath.getSqrtRatioAtTick(tick_current);
        uint160 sqrtPriceX96_lower = TickMath.getSqrtRatioAtTick(tick_lower);
        uint160 sqrtPriceX96_upper = TickMath.getSqrtRatioAtTick(tick_upper);

        uint128 liq_256 = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96_current,
            sqrtPriceX96_lower,
            sqrtPriceX96_upper,
            token0_unit,
            token1_unit
        );
        require(liq_256 <= type(uint128).max, "liq exceeds uint128 range");
        uint128 liq = uint128(liq_256);

        (uint256 amount_0, uint256 amount_1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96_current,
            sqrtPriceX96_lower,
            sqrtPriceX96_upper,
            liq
        );

        // trans to 1e18
        amount_0 = amount_0 * 1e18 / token0_unit;
        amount_1 = amount_1 * 1e18 / token1_unit;
        factor = amount_1 * 1e18 / amount_0;
    }

    function getAmountByBestLiquidity(
        uint256 factor_,
        uint256 totalValue_,
        uint256 token0_decimals,
        uint256 token1_decimals,
        uint256 token0PriceIn18,
        uint256 token1PriceIn18
    ) public view returns (uint256, uint256) {
         // why:
        // token1_amount = factor_ * token0_amount
        // totalValue_ = token0_amount * token0PriceIn18 + token1_amount * token1PriceIn18
        // totalValue_ = token0_amount * token0PriceIn18 + token0_amount * factor_ * token1PriceIn18
        // get: 
        // token0_amount = totalValue_ / (token0PriceIn18 + token1PriceIn18 * factor_)

        uint256 token0_amount = totalValue_ * 1e18 / (token0PriceIn18 + factor_ * token1PriceIn18 / 1e18);
        uint256 token1_amount = token0_amount * factor_ / 1e18;
        return (token0_amount * 10 ** token0_decimals / 1e18, token1_amount * 10 ** token1_decimals / 1e18);
    }

}