// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {TickMath} from '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import {LiquidityAmounts} from '@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol';


library LiqAmountCalculator {
    function getFactor(
        int24 tickCurrent_,
        int24 tickLower_,
        int24 tickUpper_,
        uint256 token0Decimals_,
        uint256 token1Decimals_
    ) external pure returns (uint256, uint256) {
        if (tickUpper_ < tickCurrent_) {
            // token0Amount = 0
            return (0, 1e18);
        }

        if (tickLower_ > tickCurrent_) {
            // token1Amount = 0
            return (1e18, 0);
        }

        uint256 token0Unit = 10 ** token0Decimals_;
        uint256 token1Unit = 10 ** token1Decimals_;
        uint160 sqrtPriceX96_current = TickMath.getSqrtRatioAtTick(tickCurrent_);
        uint160 sqrtPriceX96_lower = TickMath.getSqrtRatioAtTick(tickLower_);
        uint160 sqrtPriceX96_upper = TickMath.getSqrtRatioAtTick(tickUpper_);

        uint128 liq_256 = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96_current,
            sqrtPriceX96_lower,
            sqrtPriceX96_upper,
            token0Unit,
            token1Unit
        );
        require(liq_256 <= type(uint128).max, "liq exceeds uint128 range");
        uint128 liq = uint128(liq_256);

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96_current,
            sqrtPriceX96_lower,
            sqrtPriceX96_upper,
            liq
        );

        // trans to 1e18
        amount0 = amount0 * 1e18 / token0Unit;
        amount1 = amount1 * 1e18 / token1Unit;
        return (1e18, amount1 * 1e18 / amount0);
    }

    function getAmountByBestLiquidity(
        uint256 token0Factor_,
        uint256 token1Factor_,
        uint256 totalValue_,
        uint256 token0Decimals_,
        uint256 token1Decimals_,
        uint256 token0PriceIn18_,
        uint256 token1PriceIn18_
    ) public pure returns (uint256, uint256) {
        // why:
        // token1Amount = token1Factor_ * token0Amount
        // totalValue_ = token0Factor_ * token0Amount * token0PriceIn18_ + token1Factor_ * token0Amount * token1PriceIn18_
        // get: 
        // token0Amount = totalValue_ / (token0Factor_ * token0PriceIn18_ + token1PriceIn18_ * token1Factor_)

        uint256 token0Amount;
        uint256 token1Amount;
        if (token0Factor_ == 0) {
            token0Amount = 0;
            token1Amount = totalValue_ * 1e18 / token1PriceIn18_;
        } else if (token1Factor_ == 0) {
            token0Amount = totalValue_ * 1e18 / token0PriceIn18_;
            token1Amount = 0;
        } else {
            token0Amount = totalValue_ * 1e18 / (token0Factor_ * token0PriceIn18_ / 1e18 + token1Factor_ * token1PriceIn18_ / 1e18);
            token1Amount = token0Amount * token1Factor_ / 1e18;
        }

        return (token0Amount * 10 ** token0Decimals_ / 1e18, token1Amount * 10 ** token1Decimals_ / 1e18);
    }

}