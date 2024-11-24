// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// openzeppelin
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControl} from 'src/utils/AccessControl.sol';
import {IUniswapV3PoolState} from 'src/interfaces/IUniswapV3PoolState.sol';
import {IEACAggregatorProxy} from 'src/interfaces/IEACAggregatorProxy.sol';
import {ISwapRouter} from '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import {INonfungiblePositionManager} from '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
// src
import {TokenTransfer} from 'src/utils/TokenTransfer.sol';
import {UniswapV3PositionHelper} from 'src/libraries/UniswapV3PositionHelper.sol';
import {LiqAmountCalculator} from 'src/libraries/LiqAmountCalculator.sol';


contract FluxFarm is UUPSUpgradeable, AccessControl, TokenTransfer, IERC721Receiver {
    event Harvest(uint256 totalAmount0_, uint256 totalAmount1_, uint256 totalFees0_, uint256 totalFees1_);
    event SwapExactInputSingle(
        address tokenIn_,
        address tokenOut_,
        uint256 amountIn_,
        uint256 amountOutMin_,
        address recipient_,
        uint256 amountOut_
    );
    event ReBalanceToken(uint256 amount0_, uint256 amount1_);

    INonfungiblePositionManager public positionManager;
    IUniswapV3PoolState public poolState;
    ISwapRouter public swapRouter;

    address public this_;
    address public token0;
    address public token1;
    address public token0Oracle;
    address public token1Oracle;

    struct FarmingInfo {
        uint256 tokenId;
        int24 tickLower;
        int24 tickUpper;
    }

    uint256 public token0Decimals;
    uint256 public token1Decimals;
    uint256 public token0OracleDeimals;
    uint256 public token1OracleDeimals;
    uint24 public fee = 10000;

    FarmingInfo public farmingInfo;
    IUniswapV3PoolState.Slot0 public farmingSlot0;

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(DEFAULT_ADMIN_ROLE)
        override
    {}

    // Implement onERC721Received to accept NFT
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    modifier renewPool(){
        _harvest();
        _;
        _reinvest();
    }

    function initialize(
        address uniswapV3Pool_,
        address positionManager_,
        address swapRouterAddress_,
        address token0_,
        address token1_,
        address token0Oracle_,
        address token1Oracle_
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER, msg.sender);
        _grantRole(SAFE_ADMIN, msg.sender);

        this_ = address(this);
        token0 = token0_;
        token1 = token1_;
        token0Oracle = token0Oracle_;
        token1Oracle = token1Oracle_;
        
        positionManager = INonfungiblePositionManager(positionManager_);
        swapRouter = ISwapRouter(swapRouterAddress_);
        poolState = IUniswapV3PoolState(uniswapV3Pool_);
        token0Decimals = uint256(IERC20Metadata(token0).decimals());
        token1Decimals = uint256(IERC20Metadata(token1).decimals());
        token0OracleDeimals = uint256(IEACAggregatorProxy(token0Oracle).decimals());
        token1OracleDeimals = uint256(IEACAggregatorProxy(token1Oracle).decimals());
        fee = poolState.fee();

        assert(token0Decimals > 0 && token1Decimals > 0);
        assert(token0OracleDeimals > 0 && token1OracleDeimals > 0);

        IERC20(token0).approve(address(positionManager_), type(uint256).max);
        IERC20(token1).approve(address(positionManager_), type(uint256).max);

        IERC20(token0).approve(address(swapRouterAddress_), type(uint256).max);
        IERC20(token1).approve(address(swapRouterAddress_), type(uint256).max);
    }

    function swapExactInputSingle(
        address tokenIn_,
        address tokenOut_,
        uint256 amountIn_,
        uint256 amountOutMin_,
        address recipient_
    ) internal returns (uint256) {
        IERC20(tokenIn_).approve(address(swapRouter), amountIn_);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn_,
            tokenOut: tokenOut_,
            fee: fee,
            recipient: recipient_,
            deadline: block.timestamp + 1000,
            amountIn: amountIn_,
            amountOutMinimum: amountOutMin_,
            sqrtPriceLimitX96: 0
        });
        uint256 amountOut = swapRouter.exactInputSingle(params);
        emit SwapExactInputSingle(tokenIn_, tokenOut_, amountIn_, amountOutMin_, recipient_, amountOut);
        return amountOut;
    }

    function getPositionFee(uint256 tokenId_) public view returns (uint256, uint256) {
        (
            ,,,,,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = positionManager.positions(tokenId_);
        
        (uint256 fees0, uint256 fees1) = UniswapV3PositionHelper.getPositionFees(
            address(poolState),
            farmingSlot0.tick,
            tickLower,
            tickUpper,
            liquidity,
            feeGrowthInside0LastX128,
            feeGrowthInside1LastX128,
            tokensOwed0,
            tokensOwed1
        );
       
        return (fees0, fees1);
    }

    function getPriceIn1e18(address oracle_, uint256 decimals_) public view returns (uint256) {
        (, int price, , , ) = IEACAggregatorProxy(oracle_).latestRoundData();  // price is in 1e8
        require(price > 0, "Invalid price data");
        return uint256(price) * 1e18 / (10 ** decimals_);
    }

    function getPositionValue(uint256 token0Amount_, uint256 token1Amount_) public view returns (uint256) {
        uint256 token0PriceIn18 = getPriceIn1e18(token0Oracle, token0OracleDeimals);
        uint256 token1PriceIn18 = getPriceIn1e18(token1Oracle, token1OracleDeimals);

        uint256 token0Value = token0Amount_ * token0PriceIn18 / (10 ** token0Decimals);
        uint256 token1Value = token1Amount_ * token1PriceIn18 / (10 ** token1Decimals);
        return token0Value + token1Value;
    }

    function getAllPositionFees() public view returns (uint256 totalFees0, uint256 totalFees1) {
        uint256 balance = IERC721(address(positionManager)).balanceOf(this_);
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = IERC721Enumerable(address(positionManager)).tokenOfOwnerByIndex(this_, i);
            (uint256 fees0, uint256 fees1) = getPositionFee(tokenId);
            totalFees0 += fees0;
            totalFees1 += fees1;
        }
        return (totalFees0, totalFees1);        
    }

    function getAmountByBestLiquidity(
        uint256 totalValue_,
        int24 tickCurrent_,
        int24 tickLower_,
        int24 tickUpper_
    ) public view returns (uint256, uint256) {
        (uint256 token0_factor, uint256 token1_factor) = LiqAmountCalculator.getFactor(tickCurrent_, tickLower_, tickUpper_, token0Decimals, token1Decimals);

        return LiqAmountCalculator.getAmountByBestLiquidity(
            token0_factor,
            token1_factor,
            totalValue_,
            token0Decimals,
            token1Decimals,
            getPriceIn1e18(token0Oracle, token0OracleDeimals),
            getPriceIn1e18(token1Oracle, token1OracleDeimals)
        );
    }

    function _swapToken(
        uint256 amount0_,
        uint256 amount1_,
        uint256 amount0Target_,
        uint256 amount1Target_
    ) internal returns (uint256, uint256) {
        if (amount0_ > amount0Target_) {
            uint256 amount0Swap = amount0_ - amount0Target_;
            uint256 amount1Result = swapExactInputSingle(
                token0,
                token1,
                amount0Swap,
                0,
                this_
            );
            uint256 amount1Out = amount1_ + amount1Result;
            return (amount0Target_, amount1Out);
        }

        if (amount1_ > amount1Target_) {
            uint256 amount1Swap = amount1_ - amount1Target_;
            uint256 amount0Result = swapExactInputSingle(
                token1,
                token0,
                amount1Swap,
                0,
                this_
            );
            uint256 amount0Out = amount0_ + amount0Result;
            return (amount0Out, amount1Target_);
        }

        return (amount0_, amount1_);
    }

    function _harvestPosition(int24 tickCurrent_, uint256 tokenId_) internal returns (
        uint256 amount0,
        uint256 amount1,
        uint256 fee0,
        uint256 fee1
    ) {
        (,,,,,int24 tickLower,int24 tickUpper,uint128 liquidity,,,,) = positionManager.positions(tokenId_);

        // out of range
        if (tickCurrent_ < tickLower || tickCurrent_ > tickUpper) {
            // check liquidity
            if (liquidity > 0) {
                // decrease liquidity
                (amount0, amount1) = positionManager.decreaseLiquidity(
                    INonfungiblePositionManager.DecreaseLiquidityParams({
                        tokenId: tokenId_,
                        liquidity: liquidity,
                        amount0Min: amount0 * 95 / 100,         // Should set these to acceptable slippage values
                        amount1Min: amount1 * 95 / 100,         // Should set these to acceptable slippage values
                        deadline: block.timestamp + 15 minutes
                }));

                // collect
                (fee0, fee1) = positionManager.collect(
                    INonfungiblePositionManager.CollectParams({
                        tokenId: tokenId_,
                        recipient: this_,
                        amount0Max: type(uint128).max,
                        amount1Max: type(uint128).max
                }));
                return (amount0, amount1, fee0, fee1);
            }
            // no liquidity, no need to harvest
            return (0, 0, 0, 0);
        }

        // in range and has liquidity
        if (liquidity > 0) {
            // collect fee
            farmingInfo.tokenId = tokenId_;
            farmingInfo.tickLower = tickLower;
            farmingInfo.tickUpper = tickUpper;
            (fee0, fee1) = positionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: tokenId_,
                    recipient: this_,
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
            }));
            return (amount0, amount1, fee0, fee1);
        } 
        // no liquidity, no need to harvest
        return (0, 0, 0, 0);
    }

    function _harvest() internal {
        uint256 totalAmount0;
        uint256 totalAmount1;
        uint256 totalFees0;
        uint256 totalFees1;

        uint256 balance = IERC721(address(positionManager)).balanceOf(this_);
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = IERC721Enumerable(address(positionManager)).tokenOfOwnerByIndex(this_, i);
            // harvest
            (
                uint256 amount0,
                uint256 amount1,
                uint256 fee0,
                uint256 fee1
            ) = _harvestPosition(farmingSlot0.tick, tokenId);

            totalAmount0 += amount0;
            totalAmount1 += amount1;
            totalFees0 += fee0;
            totalFees1 += fee1;
        }

        emit Harvest(totalAmount0, totalAmount1, totalFees0, totalFees1);
    }

    function _rebalanceToken() internal returns (uint256, uint256) {
        uint256 token0Balance = IERC20(token0).balanceOf(this_);
        uint256 token1Balance = IERC20(token1).balanceOf(this_);
        
        uint256 totalValue = getPositionValue(
            token0Balance,
            token1Balance
        );

        (uint256 amount0Target, uint256 amount1Target) = getAmountByBestLiquidity(
            totalValue,
            farmingSlot0.tick,
            farmingInfo.tickLower,
            farmingInfo.tickUpper
        );
      
        (uint256 amount0Out, uint256 amount1Out) = _swapToken(token0Balance, token1Balance, amount0Target, amount1Target);
        emit ReBalanceToken(amount0Out, amount1Out);
        
        return (IERC20(token0).balanceOf(this_), IERC20(token1).balanceOf(this_));
    }

    function _reinvest() internal returns (uint128, uint256, uint256) {
        if (farmingInfo.tokenId == 0) {
            return (0, 0, 0);
        }

        (uint256 nowToken0Balance, uint256 nowToken1Balance) = _rebalanceToken();

        // increase liquidity
        (uint128 liquidity, uint256 amount0, uint256 amount1) = positionManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: farmingInfo.tokenId,
                amount0Desired: nowToken0Balance,
                amount1Desired: nowToken1Balance,
                amount0Min: nowToken0Balance * 95 / 100,
                amount1Min: nowToken1Balance * 95 / 100,
                deadline: block.timestamp + 15 minutes
            })
        );
       
        return (liquidity, amount0, amount1);
    }

    function initialPosition(
        int24[][] memory ticks_,
        uint256 totalValue_
    ) external onlyRole(MANAGER) {
        (
            farmingSlot0.sqrtPriceX96,
            farmingSlot0.tick,
            farmingSlot0.observationIndex,
            farmingSlot0.observationCardinality,
            farmingSlot0.observationCardinalityNext,
            farmingSlot0.feeProtocol,
            farmingSlot0.unlocked
        ) = poolState.slot0();

        uint256 balanceBefore = IERC721(address(positionManager)).balanceOf(this_);
        for (uint256 i = 0; i < ticks_.length; i++) {
            int24 tickLower = ticks_[i][0];
            int24 tickUpper = ticks_[i][1];
            (uint256 token0Amount, uint256 token1Amount) = getAmountByBestLiquidity(
                totalValue_,
                farmingSlot0.tick,
                tickLower,
                tickUpper
            );

            positionManager.mint(INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: token0Amount,
                amount1Desired: token1Amount,
                amount0Min: 0,         // Should set these to acceptable slippage values
                amount1Min: 0,         // Should set these to acceptable slippage values
                recipient: address(this),
                deadline: block.timestamp + 15 minutes
            }));
        }

        // check balances
        uint256 balanceAfter = IERC721(address(positionManager)).balanceOf(this_);
        require(balanceAfter - balanceBefore == ticks_.length, "INVALID_POSITION_COUNT");
    }

    function addAssets(address token_, uint256 amount_) external onlyRole(DEFAULT_ADMIN_ROLE) renewPool returns (uint256) {
        require(token_ == token0 || token_ == token1, "INVALID_TOKEN");
        uint256 amountReceived = doTransferIn(token_, msg.sender, amount_);
        return amountReceived;
    }

}