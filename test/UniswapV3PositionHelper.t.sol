// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";
import {UUPSProxy} from "../src/utils/UUPSProxy.sol";
import {FluxFarm} from 'src/FluxFarm.sol';
import {IUniswapV3PoolState} from 'src/interfaces/IUniswapV3PoolState.sol';
import {UniswapV3PositionHelper} from 'src/libraries/UniswapV3PositionHelper.sol';


contract UniswapV3PositionHelperTest is Test {
    
    function _calculateFeeGrowthInside(
        uint256 feeGrowthGlobalX128,
        uint256 feeGrowthOutsideLowerX128,
        uint256 feeGrowthOutsideUpperX128,
        int24 currentTick,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (bool hasOverflow, uint256 feeGrowthInsideX128) {
        unchecked {
            if (currentTick < tickLower) {
                if (feeGrowthOutsideLowerX128 < feeGrowthOutsideUpperX128) {
                    hasOverflow = true;
                    return (hasOverflow, 0); // Overflow detected
                }

                feeGrowthInsideX128 = feeGrowthOutsideLowerX128 - feeGrowthOutsideUpperX128;
            } else if (currentTick >= tickUpper) {
                if (feeGrowthOutsideUpperX128 < feeGrowthOutsideLowerX128) {
                    hasOverflow = true;
                    return (hasOverflow, 0); // Overflow detected
                }
                feeGrowthInsideX128 = feeGrowthOutsideUpperX128 - feeGrowthOutsideLowerX128;

            } else {
                if (
                    feeGrowthGlobalX128 < feeGrowthOutsideLowerX128 ||
                    feeGrowthGlobalX128 - feeGrowthOutsideLowerX128 < feeGrowthOutsideUpperX128
                ) {
                    hasOverflow = true;
                    return (hasOverflow, 0); // Overflow detected
                }
                feeGrowthInsideX128 = feeGrowthGlobalX128 - feeGrowthOutsideLowerX128 - feeGrowthOutsideUpperX128;
            }
        }

        hasOverflow = false; // No overflow detected
        return (hasOverflow, feeGrowthInsideX128);
    }

    function _calculateFeesAccrued(
        uint256 feeGrowthInsideX128,
        uint256 feeGrowthInsideLastX128,
        uint128 liquidity
    ) internal pure returns (bool hasOverflow, uint256 feesAccrued) {
        unchecked {
            // Check for underflow in fee growth delta calculation
            if (feeGrowthInsideX128 < feeGrowthInsideLastX128) {
                hasOverflow = true;
                return (hasOverflow, 0); // Overflow detected
            }
            uint256 feeGrowthDelta = feeGrowthInsideX128 - feeGrowthInsideLastX128;

            // Safe division
            feesAccrued = (uint256(liquidity) * feeGrowthDelta) / (1 << 128);
        }

        hasOverflow = false; // No overflow detected
        return (hasOverflow, feesAccrued);
    }

    function test_overflow() public {
        // currentTick < tickLower， feeGrowthOutsideLowerX128 < feeGrowthOutsideUpperX128
        // uint256 feeGrowthGlobalX128 = 10;
        // uint256 feeGrowthOutsideLowerX128 = 7;
        // uint256 feeGrowthOutsideUpperX128 = 8;
        // int24 currentTick = 264439;
        // int24 tickLower = 264400;
        // int24 tickUpper = 266200;

        // currentTick >= tickUpper, feeGrowthOutsideUpperX128 < feeGrowthOutsideLowerX128
        // uint256 feeGrowthGlobalX128 = 10;
        // uint256 feeGrowthOutsideLowerX128 = 8;
        // uint256 feeGrowthOutsideUpperX128 = 7;
        // int24 currentTick = 266300;
        // int24 tickLower = 264400;
        // int24 tickUpper = 266200;

        // tickLower < currentTick < tickUpper, feeGrowthGlobalX128 < feeGrowthOutsideLowerX128
        // uint256 feeGrowthGlobalX128 = 6;
        // uint256 feeGrowthOutsideLowerX128 = 8;
        // uint256 feeGrowthOutsideUpperX128 = 7;
        // int24 currentTick = 264439;
        // int24 tickLower = 264400;
        // int24 tickUpper = 266200;

        // tickLower < currentTick < tickUpper, feeGrowthGlobalX128 - feeGrowthOutsideLowerX128 < feeGrowthOutsideUpperX128
        uint256 feeGrowthGlobalX128 = 9;
        uint256 feeGrowthOutsideLowerX128 = 8;
        uint256 feeGrowthOutsideUpperX128 = 7;
        int24 currentTick = 264439;
        int24 tickLower = 264400;
        int24 tickUpper = 266200;

        (bool hasOverflow, uint256 feeGrowthInsideX128) = _calculateFeeGrowthInside(
            feeGrowthGlobalX128,
            feeGrowthOutsideLowerX128,
            feeGrowthOutsideUpperX128,
            currentTick,
            tickLower,
            tickUpper
        );
        assertTrue(hasOverflow, "hasOverflow should be true");
        emit log_named_uint("feeGrowthInsideX128: ", feeGrowthInsideX128);
    }
}