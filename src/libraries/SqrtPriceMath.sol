// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

library SqrtPriceMath {
    uint256 constant Q96 = 2**96;

    /// @notice caculate price from sqrtPriceX96
    /// @param sqrtPriceX96 Q64.96 format
    /// @param decimalsToken0 token0's decimals
    /// @param decimalsToken1 token1's decimals
    /// @return price in 18 decimals
    function sqrtPriceX96ToPrice(
        uint160 sqrtPriceX96,
        uint256 decimalsToken0,
        uint256 decimalsToken1
    ) external pure returns (uint256 price) {
        // Step 1: sqrtPrice = sqrtPriceX96 / Q96
        uint256 sqrtPrice = uint256(sqrtPriceX96) * 1e18 / Q96;
        // Step 2: Price = sqrtPrice^2
        uint256 rawPrice = (sqrtPrice * sqrtPrice) / 1e18;

        // Step 3: adjust precision
        if (decimalsToken0 > decimalsToken1) {
            price = rawPrice * (10**(decimalsToken0 - decimalsToken1));
        } else {
            price = rawPrice / (10**(decimalsToken1 - decimalsToken0));
        }
    }

    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function priceToSqrtPriceX96(uint256 price) external pure returns (uint160 sqrtPriceX96) {
        require(price > 0, "Price must be greater than zero");
        uint256 sqrtPrice = sqrt(price);
        uint256 sqrtPriceX96_ = sqrtPrice * Q96;
        sqrtPriceX96 = uint160(sqrtPriceX96_);
    }
}