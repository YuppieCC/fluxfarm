// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";
import {UUPSProxy} from "../src/utils/UUPSProxy.sol";
import {FluxFarmV2} from 'src/FluxFarmV2.sol';
import {IUniswapV3PoolState} from 'src/interfaces/IUniswapV3PoolState.sol';
import {UniswapV3PositionHelper} from 'src/libraries/UniswapV3PositionHelper.sol';
import {INonfungiblePositionManager} from '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';


contract FluxFarmV2DeployedTest is Test {
    bytes32 public constant MANAGER = bytes32(keccak256(abi.encodePacked("MANAGER")));

    FluxFarmV2 public fluxFarmV2;
    
    address public positionManagerAddress = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address public swapRouterAddress = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public uniswapV3PoolAddress = 0xD1F1baD4c9E6c44DeC1e9bF3B94902205c5Cd6C3;
    uint256 public slippage = 25e16;

    address public token0 = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607; // usdce
    address public token1 = 0xdC6fF44d5d932Cbd77B52E5612Ba0529DC6226F1; // wld

    address public user_ = 0xDE1e26F53aa97f02c06779F280A7DE56d06EbbaD;
    address public deployedFluxFarm = 0xfc078b6dA7eb45a858C58cD8f66e3C6d64Cd5C3F;

    uint256 public serviceFeeSlippage_ = 800000000000000000;

    function setUp() public {
        fluxFarmV2 = FluxFarmV2(deployedFluxFarm);
        vm.startPrank(user_);
        fluxFarmV2.upgradeToAndCall(address(new FluxFarmV2()), '');
        vm.stopPrank();
    }

    // function test_updateFarm() public {
    //     vm.startPrank(user_);
        // fluxFarmV2.setSlippage(20e16);
        // fluxFarmV2.AutoUpdateFarm();
        // vm.stopPrank();
    // }

    // function test_closeAllPosition() public {
    //     vm.startPrank(user_);
    //     fluxFarm.closeAllPosition(true);
    //     vm.stopPrank();
    // }

    // function test_invest() public {
    //     vm.startPrank(user_);
    //     IERC20(token0).approve(address(fluxFarmV2), IERC20(token0).balanceOf(user_));
    //     fluxFarmV2.invest(token0, IERC20(token0).balanceOf(user_));

    //     IERC20(token1).approve(address(fluxFarmV2), IERC20(token1).balanceOf(user_));
    //     fluxFarmV2.invest(token1, IERC20(token1).balanceOf(user_));
    //     vm.stopPrank();
    // }

    // function test_getPoolAddress() public {
    //     INonfungiblePositionManager positionManager = fluxFarm.positionManager();
    //     emit log_named_address("poolAddress", address(positionManager));
    // }

    // function test_getFarmingInfo() public {
    //     (uint256 tokenId, int24 tickLower, int24 tickUpper) = fluxFarmV2.getFarmingInfo();
    //     emit log_named_uint("tokenId", tokenId);
    //     emit log_named_int("tickLower", tickLower);
    //     emit log_named_int("tickUpper", tickUpper);
    // }

    function test_reinvestFromBalance() public {
        vm.startPrank(user_);
        uint256 beforebalance0 = IERC20(token0).balanceOf(address(fluxFarmV2));
        uint256 beforebalance1 = IERC20(token1).balanceOf(address(fluxFarmV2));
        emit log_named_uint("beforebalance0", beforebalance0);
        emit log_named_uint("beforebalance1", beforebalance1);
        (uint128 liquidity, uint256 amount0, uint256 amount1) = fluxFarmV2.reinvestFromBalance();
        emit log_named_uint("liquidity", liquidity);
        emit log_named_uint("amount0", amount0);
        emit log_named_uint("amount1", amount1);
        uint256 afterbalance0 = IERC20(token0).balanceOf(address(fluxFarmV2));
        uint256 afterbalance1 = IERC20(token1).balanceOf(address(fluxFarmV2));
        emit log_named_uint("afterbalance0", afterbalance0);
        emit log_named_uint("afterbalance1", afterbalance1);

        // get harvest info
        (uint256 tokenId, int24 tickLower, int24 tickUpper) = fluxFarmV2.getFarmingInfo();
        emit log_named_uint("tokenId", tokenId);
        emit log_named_int("tickLower", tickLower);
        emit log_named_int("tickUpper", tickUpper);
        vm.stopPrank();
    }
}

