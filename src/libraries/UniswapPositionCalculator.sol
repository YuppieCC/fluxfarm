pragma solidity ^0.8.0;

import {FullMath} from '@uniswap/v3-core/contracts/libraries/FullMath.sol';

library UniswapPositionCalculator {
    uint256 constant Q96 = 2**96;

    function calculateAmounts(
        uint160 sqrtPriceX96, // 当前价格 √P
        uint160 sqrtPriceAX96, // 下界价格 √P_a
        uint160 sqrtPriceBX96, // 上界价格 √P_b
        uint128 liquidity // 流动性 L
    ) external pure returns (uint256 amount0, uint256 amount1) {
        require(sqrtPriceAX96 <= sqrtPriceBX96, "Invalid price range");

        // If current price is less than lower bound, only token0 is required
        if (sqrtPriceX96 <= sqrtPriceAX96) {
            amount0 = _getAmount0ForLiquidity(sqrtPriceAX96, sqrtPriceBX96, liquidity);
            amount1 = 0;
        }
        // If current price is greater than upper bound, only token1 is required
        else if (sqrtPriceX96 >= sqrtPriceBX96) {
            amount0 = 0;
            amount1 = _getAmount1ForLiquidity(sqrtPriceAX96, sqrtPriceBX96, liquidity);
        }
        // If current price is within range, calculate both token0 and token1
        else {
            amount0 = _getAmount0ForLiquidity(sqrtPriceX96, sqrtPriceBX96, liquidity);
            amount1 = _getAmount1ForLiquidity(sqrtPriceAX96, sqrtPriceX96, liquidity);
        }
    }

    function _getAmount0ForLiquidity(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0) {
        return
            FullMath.mulDiv(
                uint256(liquidity) * Q96,
                uint256(sqrtPriceBX96) - uint256(sqrtPriceAX96),
                uint256(sqrtPriceBX96) * uint256(sqrtPriceAX96)
            );

        // uint256 numerator = uint256(amount0) * uint256(sqrtRatioAX96) * uint256(sqrtRatioBX96);
        // uint256 denominator = Q96 * (uint256(sqrtRatioBX96) - uint256(sqrtRatioAX96));
        // return numerator / denominator;
    }

    function _getAmount1ForLiquidity(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount1) {
        return
            FullMath.mulDiv(
                liquidity,
                uint256(sqrtPriceBX96) - uint256(sqrtPriceAX96),
                Q96
            );
    }
}