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
import {IFluxFarm} from 'src/interfaces/IFluxFarm.sol';


contract FluxFarm is UUPSUpgradeable, AccessControl, TokenTransfer, IERC721Receiver, IFluxFarm {
    event Invest(address token_, uint256 amount_, uint256 price_, uint256 value_, uint256 newTotalInvest_);
    event Withdraw(address token_, uint256 amount_, uint256 price_, uint256 value_, uint256 newTotalWithdraw_);
    event Harvest(uint256 totalAmount0_, uint256 totalAmount1_, uint256 totalFees0_, uint256 totalFees1_);
    event Reinvest(uint256 tokenId_, uint256 liquidity_, uint256 amount0_, uint256 amount1_);
    event UpdateFarm(address msgSender_, uint256 timestamp_, uint256 blockNumber_);
    event ReBalanceToken(uint256 amount0_, uint256 amount1_);
    event SwapExactInputSingle(
        address tokenIn_,
        address tokenOut_,
        uint256 amountIn_,
        uint256 amountOutMin_,
        address recipient_,
        uint256 amountOut_
    );
    event InitialPosition(uint256 positionCount_);
    event CloseAllPosition(
        uint256 burnCount_,
        uint256 totalAmount0_,
        uint256 totalAmount1_,
        uint256 totalFees0_,
        uint256 totalFees1_,
        uint256 nowBalanceToken0_,
        uint256 nowBalanceToken1_
    );

    INonfungiblePositionManager public positionManager;
    IUniswapV3PoolState public poolState;
    ISwapRouter public swapRouter;

    address public this_;
    address public receiver;
    address public token0;
    address public token1;
    address public token0Oracle;
    address public token1Oracle;
    uint256 public totalInvestUsdValue;
    uint256 public totalWithdrawUsdValue;

    mapping(address => uint256) public tokenInvest;
    mapping(address => uint256) public tokenWithdraw;

    struct FarmingInfo {
        uint256 tokenId;
        int24 tickLower;
        int24 tickUpper;
    }

    uint256 public token0Decimals;
    uint256 public token1Decimals;
    uint256 public token0OracleDeimals;
    uint256 public token1OracleDeimals;
    uint256 public token0Price;
    uint256 public token1Price;
    uint24 public fee = 10000;
    uint256 public slippage;

    FarmingInfo public farmingInfo;
    IUniswapV3PoolState.Slot0 public farmingSlot0;

    struct Snapshot {
        uint256 timestamp;
        // position info
        uint256 tokenId;
        uint256 amount0;
        uint256 amount1;
        // pool info
        uint160 sqrtPriceX96;
        int24 tickCurrent;
        // oracle price
        uint256 price0;
        uint256 price1;
        // balance
        uint256 balance0;
        uint256 balance1;
    }
    
    uint256 public SnapshotCount;
    mapping(uint256 => Snapshot) public snapshotInfo;

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

    modifier renewFarm(){
        _updatePrice();
        _updatePoolState();
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
        address token1Oracle_,
        uint256 slippage_
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER, msg.sender);
        _grantRole(SAFE_ADMIN, msg.sender);
        receiver = msg.sender;

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
        slippage = slippage_;

        assert(token0Decimals > 0 && token1Decimals > 0);
        assert(token0OracleDeimals > 0 && token1OracleDeimals > 0);

        IERC20(token0).approve(address(positionManager_), type(uint256).max);
        IERC20(token1).approve(address(positionManager_), type(uint256).max);

        IERC20(token0).approve(address(swapRouterAddress_), type(uint256).max);
        IERC20(token1).approve(address(swapRouterAddress_), type(uint256).max);
    }

    /// @inheritdoc IFluxFarm
    function getPositionBalance() public view returns (uint256) {
        return IERC721(address(positionManager)).balanceOf(this_);
    }

    /// @inheritdoc IFluxFarm
    function updateFarmTrigger() public view returns (bool) {
        // get tick from slot0
        (,int24 tick,,,,,) = poolState.slot0();

        // check the tick is out of range
        if (tick < farmingInfo.tickLower || tick > farmingInfo.tickUpper) {
            return true;
        }
        return false;
    }

    /// @inheritdoc IFluxFarm
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

    /// @inheritdoc IFluxFarm
    function getPriceIn1e18(address oracle_, uint256 decimals_) public view returns (uint256) {
        (, int price, , , ) = IEACAggregatorProxy(oracle_).latestRoundData();  // price is in 1e8
        require(price > 0, "Invalid price data");
        return uint256(price) * 1e18 / (10 ** decimals_);
    }

    /// @inheritdoc IFluxFarm
    function getAmountAfterSlippage(uint256 amount_, uint256 slippage_) public pure returns (uint256) {
        return amount_ * (1e18 - slippage_) / 1e18;
    }

    /// @inheritdoc IFluxFarm
    function getAmountOutMin(address tokenIn_, address tokenOut_, uint256 amountIn_) public view returns (uint256) {
        if (tokenIn_ == token0 && tokenOut_ == token1) {
            uint256 amountIn_1e18 = amountIn_ * 1e18 / (10 ** token0Decimals);
            uint256 tokenInPrice = getPriceIn1e18(token0Oracle, token0OracleDeimals);
            uint256 tokenOutPrice = getPriceIn1e18(token1Oracle, token1OracleDeimals);
            uint256 amountOutMin = getAmountAfterSlippage(amountIn_1e18 * tokenInPrice / tokenOutPrice, slippage);
            return amountOutMin * (10 ** token1Decimals) / 1e18;
        }

        if (tokenIn_ == token1 && tokenOut_ == token0) {
            uint256 amountIn_1e18 = amountIn_ * 1e18 / (10 ** token1Decimals);
            uint256 tokenInPrice = getPriceIn1e18(token1Oracle, token1OracleDeimals);
            uint256 tokenOutPrice = getPriceIn1e18(token0Oracle, token0OracleDeimals);
            uint256 amountOutMin = getAmountAfterSlippage(amountIn_1e18 * tokenInPrice / tokenOutPrice, slippage);
            return amountOutMin * (10 ** token0Decimals) / 1e18;
        }
        revert("INVALID_TOKEN");
    }

    /// @inheritdoc IFluxFarm
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

    /// @inheritdoc IFluxFarm
    function getAmountByBestLiquidity(
        uint256 totalValue_,
        int24 tickCurrent_,
        int24 tickLower_,
        int24 tickUpper_
    ) public view returns (uint256, uint256) {
        (uint256 token0_factor, uint256 token1_factor) = LiqAmountCalculator.getFactor(
            tickCurrent_,
            tickLower_,
            tickUpper_,
            token0Decimals,
            token1Decimals
        );

        return LiqAmountCalculator.getAmountByBestLiquidity(
            token0_factor,
            token1_factor,
            totalValue_,
            token0Decimals,
            token1Decimals,
            token0Price,
            token1Price
        );
    }

    /**
    * @notice swap token with exact input single
    */
    function _swapExactInputSingle(
        address tokenIn_,
        address tokenOut_,
        uint256 amountIn_,
        address recipient_
    ) internal returns (uint256) {
        IERC20(tokenIn_).approve(address(swapRouter), amountIn_);
        uint256 amountOutMin = getAmountOutMin(tokenIn_, tokenOut_, amountIn_);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn_,
            tokenOut: tokenOut_,
            fee: fee,
            recipient: recipient_,
            deadline: block.timestamp + 1000,
            amountIn: amountIn_,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0
        });
        uint256 amountOut = swapRouter.exactInputSingle(params);
        emit SwapExactInputSingle(tokenIn_, tokenOut_, amountIn_, amountOutMin, recipient_, amountOut);
        return amountOut;
    }

    /**
    * @notice get the value of position
    * @param token0Amount_ uint256
    * @param token1Amount_ uint256
    * @return value
    */
    function _getPositionValue(uint256 token0Amount_, uint256 token1Amount_) internal view returns (uint256) {
        // upadte price before calculate the value of position 
        uint256 token0Value = token0Amount_ * token0Price / (10 ** token0Decimals);
        uint256 token1Value = token1Amount_ * token1Price / (10 ** token1Decimals);
        return token0Value + token1Value;
    }

    /**
    * @notice update the token0 and token1 price, transfer the price from oracle(1e8) to 1e18
    */
    function _updatePrice() internal {
        token0Price = getPriceIn1e18(token0Oracle, token0OracleDeimals);
        token1Price = getPriceIn1e18(token1Oracle, token1OracleDeimals);
    }

    /**
    * @notice snapshot the position info
    * @param amount0_ uint256
    * @param amount1_ uint256
    */
    function _snapshot(uint256 amount0_, uint256 amount1_) internal {
        SnapshotCount++;
        snapshotInfo[SnapshotCount] = Snapshot({
            timestamp: block.timestamp,
            tokenId: farmingInfo.tokenId,
            amount0:  amount0_,
            amount1:  amount1_,
            sqrtPriceX96: farmingSlot0.sqrtPriceX96,
            tickCurrent:  farmingSlot0.tick,
            price0: token0Price,
            price1: token1Price,
            balance0: IERC20(token0).balanceOf(this_),
            balance1: IERC20(token1).balanceOf(this_)
        });
    }

    /**
    * @notice update the pool state
    */
    function _updatePoolState() internal {
        (
            farmingSlot0.sqrtPriceX96,
            farmingSlot0.tick,
            farmingSlot0.observationIndex,
            farmingSlot0.observationCardinality,
            farmingSlot0.observationCardinalityNext,
            farmingSlot0.feeProtocol,
            farmingSlot0.unlocked
        ) = poolState.slot0();
    }

    /**
    * @notice swap token if the amount of token0 or token1 is not enough
    * @param amount0_ uint256
    * @param amount1_ uint256
    * @param amount0Target_ uint256
    * @param amount1Target_ uint256
    * @return amount0Out, amount1Out
    */
    function _swapToken(
        uint256 amount0_,
        uint256 amount1_,
        uint256 amount0Target_,
        uint256 amount1Target_
    ) internal returns (uint256, uint256) {
        if (amount0_ > amount0Target_) {
            // swap token0 to token1
            uint256 amount0Swap = amount0_ - amount0Target_;
            uint256 amount1Result = _swapExactInputSingle(
                token0,
                token1,
                amount0Swap,
                this_
            );
            uint256 amount1Out = amount1_ + amount1Result;
            return (amount0Target_, amount1Out);
        }

        if (amount1_ > amount1Target_) {
            // swap token1 to token0
            uint256 amount1Swap = amount1_ - amount1Target_;
            uint256 amount0Result = _swapExactInputSingle(
                token1,
                token0,
                amount1Swap,
                this_
            );
            uint256 amount0Out = amount0_ + amount0Result;
            return (amount0Out, amount1Target_);
        }

        // no need to swap
        return (amount0_, amount1_);
    }

    /**
    * @notice close the position, decrease liquidity if has liquidity and collect the fee
    * @param tokenId_ uint256
    * @param liquidity_ uint128
    */
    function _closePosition(uint256 tokenId_, uint128 liquidity_) internal returns (
        uint256 amount0,
        uint256 amount1,
        uint256 fee0,
        uint256 fee1
    ) {
        if (liquidity_ > 0) {
            // decrease liquidity if has liquidity
            (amount0, amount1) = positionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId_,
                liquidity: liquidity_,
                amount0Min: 0,
                amount1Min: 0,
                    deadline: block.timestamp + 15 minutes
                })
            );

            // collect
            (fee0, fee1) = positionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: tokenId_,
                    recipient: this_,
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
            }));
        }
    }

    /**
    * @notice harvest the position, close position if out of range, collect the fee if has liquidity and position in range
    * @param tickCurrent_ int24
    * @param tokenId_ uint256
    */
    function _harvestPosition(int24 tickCurrent_, uint256 tokenId_) internal returns (
        uint256 amount0,
        uint256 amount1,
        uint256 fee0,
        uint256 fee1
    ) {
        (,,,,,int24 tickLower,int24 tickUpper,uint128 liquidity,,,,) = positionManager.positions(tokenId_);

        // out of range
        if (tickCurrent_ < tickLower || tickCurrent_ > tickUpper) {
            return _closePosition(tokenId_, liquidity);
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

    /**
    * @notice harvest all positions
    */
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

    /**
    * @notice rebalance the token0 and token1 balance
    * @return token0Balance, token1Balance
    */
    function _rebalanceToken() internal returns (uint256, uint256) {
        uint256 token0Balance = IERC20(token0).balanceOf(this_);
        uint256 token1Balance = IERC20(token1).balanceOf(this_);
        
        uint256 totalValue = _getPositionValue(
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

    /**
    * @notice reinvest the token, rebalance the token0 and token1 balance, increase liquidity if has position, snapshot the position info
    * @return liquidity, amount0, amount1
    */
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
                amount0Min: getAmountAfterSlippage(nowToken0Balance, slippage),
                amount1Min: getAmountAfterSlippage(nowToken1Balance, slippage),
                deadline: block.timestamp + 15 minutes
            })
        );

        _snapshot(amount0, amount1);
       
        emit Reinvest(farmingInfo.tokenId, liquidity, amount0, amount1);
        return (liquidity, amount0, amount1);
    }

    /**
    * @notice get the token info, returns the decimals and price
    * @param token_ address
    */
    function _getTokenInfo(address token_) internal view returns (
        uint256 tokenDecimals,
        uint256 tokenPrice
    ) {
        if (token_ == token0) {
            tokenDecimals = token0Decimals;
            tokenPrice = getPriceIn1e18(token0Oracle, token0OracleDeimals);
        } else {
            tokenDecimals = token1Decimals;
            tokenPrice = getPriceIn1e18(token1Oracle, token1OracleDeimals);
        }
    }

    /// @inheritdoc IFluxFarm
    function setSlippage(uint256 slippage_) external onlyRole(MANAGER) {
        require(slippage_ > 0 && slippage_ < 1e18, "INVALID_SLIPPAGE");
        slippage = slippage_;
    }

    /// @inheritdoc IFluxFarm
    function setReceiver(address receiver_) external onlyRole(SAFE_ADMIN) {
        receiver = receiver_;
    }

    /// @inheritdoc IFluxFarm
    function claimTokens(address token_, address to_, uint256 amount_) external onlyRole(SAFE_ADMIN) {
        require(to_ == receiver, "INVALID_RECEIVER");
        if (token_ == address(0)) {
            safeTransferETH(receiver, amount_);
        } else {
            doTransferOut(token_, receiver, amount_);
        }
    }

    /// @inheritdoc IFluxFarm
    function initialPosition(
        int24[][] memory ticks_,
        uint256 onePositionValue_
    ) external onlyRole(MANAGER) returns (uint256) {
        _updatePoolState();
        _updatePrice();

        uint256 balanceBefore = IERC721(address(positionManager)).balanceOf(this_);
        require(balanceBefore == 0, "ALREADY_INITIAL_POSITION");

        for (uint256 i = 0; i < ticks_.length; i++) {
            int24 tickLower = ticks_[i][0];
            int24 tickUpper = ticks_[i][1];
            (uint256 token0Amount, uint256 token1Amount) = getAmountByBestLiquidity(
                onePositionValue_,
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
                amount0Min: getAmountAfterSlippage(token0Amount, slippage),
                amount1Min: getAmountAfterSlippage(token1Amount, slippage),
                recipient: this_,
                deadline: block.timestamp + 15 minutes
            }));            
        }

        // check balances
        uint256 balanceAfter = IERC721(address(positionManager)).balanceOf(this_);
        require(balanceAfter - balanceBefore == ticks_.length, "INVALID_POSITION_COUNT");

        emit InitialPosition(ticks_.length);
        return ticks_.length;
    }

    /// @inheritdoc IFluxFarm
    function closeAllPosition(bool isBurn_) external onlyRole(MANAGER) returns (
        uint256 burnCount,
        uint256 totalAmount0,
        uint256 totalAmount1,
        uint256 totalFees0,
        uint256 totalFees1,
        uint256 nowBalanceToken0,
        uint256 nowBalanceToken1
    ) {
        uint256 balance = IERC721(address(positionManager)).balanceOf(this_);
        uint256[] memory tokenIds = new uint256[](balance);

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = IERC721Enumerable(address(positionManager)).tokenOfOwnerByIndex(this_, i);
            (,,,,,,,uint128 liquidity,,,,) = positionManager.positions(tokenId);
            (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1) = _closePosition(tokenId, liquidity);
            totalAmount0 += amount0;
            totalAmount1 += amount1;
            totalFees0 += fee0;
            totalFees1 += fee1;
            
            tokenIds[i] = tokenId;  // prepare for burn
        }

        if (isBurn_) {
            for (uint256 i = 0; i < balance; i++) {
                positionManager.burn(tokenIds[i]);
                burnCount++;
            }
        }

        nowBalanceToken0 = IERC20(token0).balanceOf(this_);
        nowBalanceToken1 = IERC20(token1).balanceOf(this_);
        
        emit CloseAllPosition(
            burnCount,
            totalAmount0,
            totalAmount1,
            totalFees0,
            totalFees1,
            nowBalanceToken0,
            nowBalanceToken1
        );
    }

    /// @inheritdoc IFluxFarm
    function invest(address token_, uint256 amount_) external onlyRole(MANAGER) renewFarm returns (uint256) {
        require(token_ == token0 || token_ == token1, "INVALID_TOKEN");
        (uint256 tokenDecimals, uint256 tokenPrice) = _getTokenInfo(token_);

        uint256 amountReceived = doTransferIn(token_, msg.sender, amount_);  // transfer in
        uint256 tokenValue = amountReceived * tokenPrice / (10 ** tokenDecimals);  // convert to usd

        tokenInvest[token_] += amountReceived;  // update balance
        uint256 newTotalInvestUsdValue = totalInvestUsdValue + tokenValue;
        require(newTotalInvestUsdValue > totalInvestUsdValue, "Amount Overflow");
        totalInvestUsdValue = newTotalInvestUsdValue;

        emit Invest(token_, amountReceived, tokenPrice, tokenValue, newTotalInvestUsdValue);
        return tokenValue;
    }

    /// @inheritdoc IFluxFarm
    function withdraw(address token_, uint256 amount_) external onlyRole(SAFE_ADMIN) renewFarm returns (uint256) {
        require(token_ == token0 || token_ == token1, "INVALID_TOKEN");
        (uint256 tokenDecimals, uint256 tokenPrice) = _getTokenInfo(token_);

        uint256 amountWithdraw = doTransferOut(token_, msg.sender, amount_);  // transfer out
        uint256 tokenValue = amountWithdraw * tokenPrice / (10 ** tokenDecimals);  // convert to usd

        tokenWithdraw[token_] += amountWithdraw;  // update balance
        uint256 newTotalWithdrawUsdValue = totalWithdrawUsdValue + tokenValue;
        require(newTotalWithdrawUsdValue > totalWithdrawUsdValue, "Amount Overflow");
        totalWithdrawUsdValue = newTotalWithdrawUsdValue;

        emit Withdraw(token_, amountWithdraw, tokenPrice, tokenValue, totalWithdrawUsdValue);
        return tokenValue;
    }

    /// @inheritdoc IFluxFarm
    function updateFarm() external onlyRole(MANAGER) renewFarm returns (bool) {
        emit UpdateFarm(msg.sender, block.timestamp, block.number);
        return true;
    }
}
