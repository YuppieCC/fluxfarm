pragma solidity ^0.8.24;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {PositionConfig} from "@uniswap/v4-periphery/test/shared/PositionConfig.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {LiquidityOperations} from "@uniswap/v4-periphery/test/shared/LiquidityOperations.sol";
// import HookSavesDelta
import {HookSavesDelta} from "@uniswap/v4-periphery/test/shared/HookSavesDelta.sol";

contract UniswapV4Test is Test, Deployers, LiquidityOperations {
    address public user_ = 0xDE1e26F53aa97f02c06779F280A7DE56d06EbbaD;
    address public deployedUniswapV4PositionManager = 0x3C3Ea4B57a46241e54610e5f022E5c45859A1017;

    address hookAddr = address(uint160(Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG));
    PoolKey poolKey;

    address public currency0Address = address(0);
    address public currency1Address = 0xdC6fF44d5d932Cbd77B52E5612Ba0529DC6226F1; // wld

    function setUp() public {
        lpm = IPositionManager(deployedUniswapV4PositionManager);

        Currency currency0 = Currency.wrap(currency0Address); // tokenAddress1 = 0 for native ETH
        Currency currency1 = Currency.wrap(currency1Address);
        // initpool
        poolKey = PoolKey(currency0, currency1, 3000, 60, IHooks(address(0)));
    }

    function test_mint_toRecipient() public {
        int24 tickLower = int24(75060);
        int24 tickUpper = int24(77160);
        uint256 amount0Desired = 4393913282739698;
        uint256 amount1Desired = 33463195382618230000;
        uint256 liquidityToAdd = LiquidityAmounts.getLiquidityForAmounts(
            SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            amount0Desired,
            amount1Desired
        );

        PositionConfig memory config = PositionConfig({poolKey: poolKey, tickLower: tickLower, tickUpper: tickUpper});

        // mint to specific recipient, not using the recipient constants
        vm.startPrank(user_);
        // IERC20(currency0Address).approve(address(lpm), amount0Desired);
        IERC20(currency1Address).approve(address(lpm), amount1Desired);
        // mint(config, liquidityToAdd, user_, ZERO_BYTES);
        mintWithNative(0, config, liquidityToAdd, user_, ZERO_BYTES);
        vm.stopPrank();
    
    }

}