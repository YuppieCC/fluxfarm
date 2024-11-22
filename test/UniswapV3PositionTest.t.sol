// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {ISwapRouter} from '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import {INonfungiblePositionManager} from '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import {SqrtPriceMath} from 'src/libraries/SqrtPriceMath.sol';
import {TickMath} from '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import {LiquidityAmounts} from '@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol';
import {LiqAmountCalculator} from 'src/libraries/LiqAmountCalculator.sol';
import {IEACAggregatorProxy} from 'src/interfaces/IEACAggregatorProxy.sol';
import {IUniswapV3PoolState} from 'src/interfaces/IUniswapV3PoolState.sol';
import {UniswapV3PositionHelper} from 'src/libraries/UniswapV3PositionHelper.sol';


contract UniswapV3PositionTest is Test {
    uint256 constant Q96 = 2**96;
    INonfungiblePositionManager public positionManager;
    IEACAggregatorProxy public priceOracle;
    IUniswapV3PoolState public poolState;
    // IUniswapV3Factory public factory;
    ISwapRouter public swapRouter;

    uint24 public fee = 10000;

    struct FarmingInfo {
        uint256 tokenId;
        int24 tickLower;
        int24 tickUpper;
    }

    uint256 public token0_decimals;
    uint256 public token1_decimals;
    uint256 public token0_oracle_deimals;
    uint256 public token1_oracle_deimals;
    FarmingInfo public farmingInfo;
    IUniswapV3PoolState.Slot0 public farming_slot0;

    address public positionManagerAddress = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    // address public factoryAddress = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address public swapRouterAddress = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public uniswapV3PoolAddress = 0xD1F1baD4c9E6c44DeC1e9bF3B94902205c5Cd6C3;

    address public token0 = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607; // usdce
    address public token1 = 0xdC6fF44d5d932Cbd77B52E5612Ba0529DC6226F1; // wld

    address public token0_oracle = 0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3;  // usdce-usd
    address public token1_oracle = 0x4e1C6B168DCFD7758bC2Ab9d2865f1895813D236;  // wld-usd

    address public user_ = 0xDE1e26F53aa97f02c06779F280A7DE56d06EbbaD;

    int24[][] public ticks = [
        [int24(252200), int24(254800)],
        [int24(254000), int24(256600)],
        [int24(255800), int24(258400)],
        [int24(257600), int24(260200)],
        [int24(259400), int24(262000)],
        [int24(261200), int24(263800)],
        [int24(263000), int24(265800)],
        [int24(265000), int24(267600)],
        [int24(266800), int24(269400)],
        [int24(268600), int24(271200)],
        [int24(270400), int24(273000)],
        [int24(272200), int24(274800)],
        [int24(272600), int24(275200)],
        [int24(274400), int24(277000)],
        [int24(276200), int24(278800)],
        [int24(278000), int24(280600)],
        [int24(279800), int24(282400)],
        [int24(281600), int24(284200)],
        [int24(283400), int24(286000)],
        [int24(285200), int24(288000)],
        [int24(287200), int24(289800)],
        [int24(289000), int24(291600)],
        [int24(290800), int24(293400)],
        [int24(292600), int24(295200)]
    ];
   
    function setUp() public {
        positionManager = INonfungiblePositionManager(positionManagerAddress);
        swapRouter = ISwapRouter(swapRouterAddress);
        poolState = IUniswapV3PoolState(uniswapV3PoolAddress);
        vm.deal(user_, 1000e18);

        token0_decimals = uint256(IERC20Metadata(token0).decimals());
        token1_decimals = uint256(IERC20Metadata(token1).decimals());
        token0_oracle_deimals = uint256(IEACAggregatorProxy(token0_oracle).decimals());
        token1_oracle_deimals = uint256(IEACAggregatorProxy(token1_oracle).decimals());
        (
            farming_slot0.sqrtPriceX96,
            farming_slot0.tick,
            farming_slot0.observationIndex,
            farming_slot0.observationCardinality,
            farming_slot0.observationCardinalityNext,
            farming_slot0.feeProtocol,
            farming_slot0.unlocked
        ) = poolState.slot0();

        assert(token0_decimals > 0 && token1_decimals > 0);
        assert(token0_oracle_deimals > 0 && token1_oracle_deimals > 0);

    }

    function swap_exactInputSingle(
        address user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address recipient
    ) public returns (uint256) {
        vm.startPrank(user);
        IERC20(tokenIn).approve(address(swapRouter), amountIn);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: recipient,
            deadline: block.timestamp + 1000,
            amountIn: amountIn,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0
        });
        uint256 amountOut = swapRouter.exactInputSingle(params);
        emit log_named_uint("amountOut: ", amountOut);
        vm.stopPrank();
        return amountOut;
    }

    function sqrtPriceX96ToPrice(uint160 sqrtPriceX96, uint256 decimalsToken0, uint256 decimalsToken1) internal pure returns (uint256) {
        return SqrtPriceMath.sqrtPriceX96ToPrice(sqrtPriceX96, decimalsToken0, decimalsToken1);
    }

    function getPositionFee(uint256 tokenId) public returns (uint256, uint256) {
        (
            ,,,,,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = positionManager.positions(tokenId);
        
        (uint256 fees0, uint256 fees1) = UniswapV3PositionHelper.getPositionFees(
            uniswapV3PoolAddress,
            farming_slot0.tick,
            tickLower,
            tickUpper,
            liquidity,
            feeGrowthInside0LastX128,
            feeGrowthInside1LastX128,
            tokensOwed0,
            tokensOwed1
        );
        emit log_named_uint("fees0: ", fees0);
        emit log_named_uint("fees1: ", fees1);
        return (fees0, fees1);
    }

    function getPriceIn1e18(address oracleAddress_, uint256 oracle_decimals) internal view returns (uint256) {
        (, int price, , , ) = IEACAggregatorProxy(oracleAddress_).latestRoundData();  // price is in 1e8
        require(price > 0, "Invalid price data");
        return uint256(price) * 1e18 / (10 ** oracle_decimals);
    }

    function getPositionValue(uint256 token0_amount, uint256 token1_amount) public view returns (uint256) {
        uint256 token0PriceIn18 = getPriceIn1e18(token0_oracle, token0_oracle_deimals);
        uint256 token1PriceIn18 = getPriceIn1e18(token1_oracle, token1_oracle_deimals);

        uint256 token0_usd_value = token0_amount * token0PriceIn18 / (10 ** token0_decimals);
        uint256 token1_usd_value = token1_amount * token1PriceIn18 / (10 ** token1_decimals);
        return token0_usd_value + token1_usd_value;
    }

    function getAllPositionFees() public returns (uint256 total_fees0, uint256 total_fees1) {
        uint256 balance = IERC721(positionManagerAddress).balanceOf(user_);
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = IERC721Enumerable(positionManagerAddress).tokenOfOwnerByIndex(user_, i);
            emit log_named_uint("tokenId: ", tokenId);
            // harvest
            (uint256 fees0, uint256 fees1) = getPositionFee(tokenId);
            total_fees0 += fees0;
            total_fees1 += fees1;
        }
        return (total_fees0, total_fees1);        
    }

    function calculateRange(uint256 now_price) public pure returns (uint256 min_price, uint256 max_price) {
        min_price = now_price * 70 / 100;
        max_price = now_price * 130 / 100;
    }

    function getAmountByBestLiquidity(
        uint256 totalValue_,
        int24 tick_current,
        int24 tick_lower,
        int24 tick_upper
    ) public returns (uint256, uint256) {
        (uint256 token0_factor, uint256 token1_factor) = LiqAmountCalculator.getFactor(tick_current, tick_lower, tick_upper, token0_decimals, token1_decimals);
        emit log_named_uint("token0_factor: ", token0_factor);
        emit log_named_uint("token1_factor: ", token1_factor);

        return LiqAmountCalculator.getAmountByBestLiquidity(
            token0_factor,
            token1_factor,
            totalValue_,
            token0_decimals,
            token1_decimals,
            getPriceIn1e18(token0_oracle, token0_oracle_deimals),
            getPriceIn1e18(token1_oracle, token1_oracle_deimals)
        );
    }

    function swap_token(
        address user,
        uint256 amount0,
        uint256 amount1,
        uint256 amount0_target,
        uint256 amount1_target
    ) internal returns (uint256, uint256) {
        if (amount0 > amount0_target) {
            uint256 amount0_swap = amount0 - amount0_target;
            uint256 amount1_result = swap_exactInputSingle(
                user,
                token0,
                token1,
                amount0_swap,
                0,
                user
            );
            uint256 amount1_out = amount1 + amount1_result;
            return (amount0_target, amount1_out);
        }

        if (amount1 > amount1_target) {
            uint256 amount1_swap = amount1 - amount1_target;
            uint256 amount0_result = swap_exactInputSingle(
                user,
                token1,
                token0,
                amount1_swap,
                0,
                user
            );
            uint256 amount0_out = amount0 + amount0_result;
            return (amount0_out, amount1_target);
        }
    }

    function rebalance_position(address user) internal returns (uint256, uint256) {
        uint256 token0_balance = IERC20(token0).balanceOf(user);
        uint256 token1_balance = IERC20(token1).balanceOf(user);
        
        uint256 totalValue = getPositionValue(
            token0_balance,
            token1_balance
        );
        emit log_named_uint("totalValue: ", totalValue);

        (uint256 amount0_target, uint256 amount1_target) = getAmountByBestLiquidity(
            totalValue,
            farming_slot0.tick,
            farmingInfo.tickLower,
            farmingInfo.tickUpper
        );
        emit log_named_uint("token0_amount: ", amount0_target);
        emit log_named_uint("token1_amount: ", amount1_target);

        (uint256 amount0_out, uint256 amount1_out) = swap_token(user_, token0_balance, token1_balance, amount0_target, amount1_target);
        emit log_named_uint("amount0_out: ", amount0_out);
        emit log_named_uint("amount1_out: ", amount1_out);

        uint256 now_token0_balance = IERC20(token0).balanceOf(user_);
        uint256 now_token1_balance = IERC20(token1).balanceOf(user_);
        emit log_named_uint("now_token0_balance: ", now_token0_balance);
        emit log_named_uint("now_token1_balance: ", now_token1_balance);
        // return (
        //     IERC20(token0).balanceOf(user_),
        //     IERC20(token1).balanceOf(user_)
        // );
        return (now_token0_balance, now_token1_balance);
    }

    function _harvest(int24 tickCurrent, uint256 tokenId) internal returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1) {
        (,,,,,int24 tickLower,int24 tickUpper,uint128 liquidity,,,,) = positionManager.positions(tokenId);

        // out of range
        if (tickCurrent < tickLower || tickCurrent > tickUpper) {
            // check liquidity
            if (liquidity > 0) {
                // decrease liquidity
                (amount0, amount1) = positionManager.decreaseLiquidity(
                    INonfungiblePositionManager.DecreaseLiquidityParams({
                        tokenId: tokenId,
                        liquidity: liquidity,
                        amount0Min: 0,         // Should set these to acceptable slippage values
                        amount1Min: 0,         // Should set these to acceptable slippage values
                        deadline: block.timestamp + 15 minutes
                }));

                // collect
                (fee0, fee1) = positionManager.collect(
                    INonfungiblePositionManager.CollectParams({
                        tokenId: tokenId,
                        recipient: user_,
                        amount0Max: type(uint128).max,
                        amount1Max: type(uint128).max
                }));
                return (amount0, amount1, fee0, fee1);
            } else {
                // no liquidity, no need to harvest
                return (0, 0, 0, 0);
            }
        } else {
            // in range
            if (liquidity > 0) {
                // collect fee
                farmingInfo.tokenId = tokenId;
                farmingInfo.tickLower = tickLower;
                farmingInfo.tickUpper = tickUpper;
                (fee0, fee1) = positionManager.collect(
                    INonfungiblePositionManager.CollectParams({
                        tokenId: tokenId,
                        recipient: user_,
                        amount0Max: type(uint128).max,
                        amount1Max: type(uint128).max
                }));
                return (amount0, amount1, fee0, fee1);
            } else {
                // no liquidity, no need to harvest
                return (0, 0, 0, 0);
            }
        }        
    }

    function harvest() public {
        uint256 balance = IERC721(positionManagerAddress).balanceOf(user_);
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = IERC721Enumerable(positionManagerAddress).tokenOfOwnerByIndex(user_, i);
            emit log_named_uint("tokenId: ", tokenId);
            // harvest
            (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1) = _harvest(farming_slot0.tick, tokenId);
            emit log_named_uint("amount0: ", amount0);
            emit log_named_uint("amount1: ", amount1);
            emit log_named_uint("fee0: ", fee0);
            emit log_named_uint("fee1: ", fee1);
        }
    }

    function _reinvest() public returns (uint128, uint256, uint256) {
        if (farmingInfo.tokenId == 0) {
            emit log("No position to reinvest");
            return (0, 0, 0);
        }

        (uint256 amount0_out, uint256 amount1_out) = rebalance_position(user_);

        vm.startPrank(user_);
        // increase liquidity
        (uint128 liquidity, uint256 amount0, uint256 amount1) = positionManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: farmingInfo.tokenId,
                amount0Desired: amount0_out,
                amount1Desired: amount1_out,
                amount0Min: amount0_out * 9 / 100,
                amount1Min: amount1_out * 9 / 100,
                deadline: block.timestamp + 15 minutes
            })
        );
        emit log_named_uint("farming_tokenId: ", farmingInfo.tokenId);
        emit log_named_uint("liquidity: ", liquidity);
        emit log_named_uint("amount0: ", amount0);
        emit log_named_uint("amount1: ", amount1);
        vm.stopPrank();
        return (liquidity, amount0, amount1);
    }

    function test_getPositionValue() public {
        uint256 token0_amount = 1000 * (10 ** token0_decimals);
        uint256 token1_amount = 1000 * (10 ** token1_decimals);
        uint256 value = getPositionValue(token0_amount, token1_amount);
        emit log_named_uint("value: ", value);
    }

    function test_sqrtPriceX96ToPrice() public {
        uint160 sqrtPriceX96 = 52211182093678445753969948736418719;  // 
        uint256 now_price = sqrtPriceX96ToPrice(sqrtPriceX96, token0_decimals, token1_decimals);
        (uint256 min_price, uint256 max_price) = calculateRange(now_price);
        emit log_named_uint("now_price: ", now_price);
        emit log_named_uint("min_price: ", min_price);
        emit log_named_uint("max_price: ", max_price);

        uint160 min_sqrtPriceX96 = SqrtPriceMath.priceToSqrtPriceX96(min_price);
        uint160 max_sqrtPriceX96 = SqrtPriceMath.priceToSqrtPriceX96(max_price);
        emit log_named_uint("min_sqrtPriceX96: ", min_sqrtPriceX96);
        emit log_named_uint("max_sqrtPriceX96: ", max_sqrtPriceX96);

        int24 min_tick = TickMath.getTickAtSqrtRatio(min_sqrtPriceX96);
        int24 max_tick = TickMath.getTickAtSqrtRatio(max_sqrtPriceX96);
        emit log_named_int("min_tick: ", min_tick);
        emit log_named_int("max_tick: ", max_tick);

        uint160 sqrtPriceX96_lower = TickMath.getSqrtRatioAtTick(min_tick);
        uint160 sqrtPriceX96_upper = TickMath.getSqrtRatioAtTick(max_tick);
        emit log_named_uint("sqrtPriceX96_lower: ", sqrtPriceX96_lower);
        emit log_named_uint("sqrtPriceX96_upper: ", sqrtPriceX96_upper);

        uint256 _min_price = sqrtPriceX96ToPrice(sqrtPriceX96_lower, token0_decimals, token1_decimals);
        uint256 _max_price = sqrtPriceX96ToPrice(sqrtPriceX96_upper, token0_decimals, token1_decimals);
        emit log_named_uint("fact min_price: ", _min_price);
        emit log_named_uint("fact max_price: ", _max_price);
    }

    function test_tick_math() public {
        int24 tick_lower = 265000;
        int24 tick_upper = 271200;
        uint160 sqrtPriceX96_lower = TickMath.getSqrtRatioAtTick(tick_lower);
        uint160 sqrtPriceX96_upper = TickMath.getSqrtRatioAtTick(tick_upper);
        emit log_named_uint("sqrtPriceX96_lower: ", sqrtPriceX96_lower);
        emit log_named_uint("sqrtPriceX96_upper: ", sqrtPriceX96_upper);

        uint256 price_lower = sqrtPriceX96ToPrice(sqrtPriceX96_lower, 6, 18);
        uint256 price_upper = sqrtPriceX96ToPrice(sqrtPriceX96_upper, 6, 18);
        emit log_named_uint("price_lower: ", price_lower);
        emit log_named_uint("price_upper: ", price_upper);

        int24 original_ticker_lower = TickMath.getTickAtSqrtRatio(sqrtPriceX96_lower);
        int24 original_ticker_upper = TickMath.getTickAtSqrtRatio(sqrtPriceX96_upper);
        emit log_named_int("original_ticker_lower: ", original_ticker_lower);
        emit log_named_int("original_ticker_upper: ", original_ticker_upper);   
    }

    function test_liquidity_amounts() public {
        int24 tick_current = 281200;
        int24 tick_lower = 265000;
        int24 tick_upper = 271200;
        uint256 totalValue = 16e18;
        
        (uint256 token0_amount, uint256 token1_amount) = getAmountByBestLiquidity(totalValue, tick_current, tick_lower, tick_upper);
        emit log_named_uint("token0_amount: ", token0_amount);
        emit log_named_uint("token1_amount: ", token1_amount);
    }

    function initial_position() public {
        uint256 totalValue = 1e16;

        for (uint256 i = 0; i < ticks.length; i++) {
            int24 tick_lower = ticks[i][0];
            int24 tick_upper = ticks[i][1];
            (uint256 token0_amount, uint256 token1_amount) = getAmountByBestLiquidity(totalValue, farming_slot0.tick, tick_lower, tick_upper);
            // emit log_named_uint("token0_amount: ", token0_amount);
            // emit log_named_uint("token1_amount: ", token1_amount);

            INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: tick_lower,
                tickUpper: tick_upper,
                amount0Desired: token0_amount * 9 / 10,
                amount1Desired: token1_amount * 9 / 10,
                amount0Min: 0,         // Should set these to acceptable slippage values
                amount1Min: 0,         // Should set these to acceptable slippage values
                recipient: user_,
                deadline: block.timestamp + 15 minutes
            });

            vm.startPrank(user_);
            positionManager.mint(params);
            // (uint tokenId, uint liquidity, uint amount0, uint amount1) = positionManager.mint(params);
            // emit log_named_uint("tokenId: ", tokenId);
            // emit log_named_uint("liquidity: ", liquidity);
            // emit log_named_uint("amount0: ", amount0);
            // emit log_named_uint("amount1: ", amount1);
            vm.stopPrank();
            // break;
        }

        // check balances
        uint256 balance = IERC721(positionManagerAddress).balanceOf(user_);
        assertTrue(balance >= ticks.length);
        emit log_named_uint("Position balance: ", balance);
    }

    function test_reinvest() public {
        vm.startPrank(user_);
        harvest();
        _reinvest();
        vm.stopPrank();
    }

    function test_getAllPositionFees() public {
        (uint256 total_fees0, uint256 total_fees1) = getAllPositionFees();
        emit log_named_uint("total_fees0: ", total_fees0);
        emit log_named_uint("total_fees1: ", total_fees1);
    }

}