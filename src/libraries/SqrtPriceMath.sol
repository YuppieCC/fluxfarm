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
        require(price > 0, "Price must be greater than 0");

        // Scale price up to 2^192 for sqrtPriceX96 computation
        uint256 scaledPrice = price << 192; // Equivalent to multiplying by 2^192

        // Take the square root of the scaled price
        uint256 sqrtPrice = sqrt(scaledPrice);

        // Ensure the result fits in uint160
        require(sqrtPrice <= type(uint160).max, "sqrtPrice exceeds uint160 range");
        sqrtPriceX96 = uint160(sqrtPrice);
    }

}