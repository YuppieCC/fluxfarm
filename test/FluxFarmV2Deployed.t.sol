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
    address public deployedFluxFarm = 0xF85cc35AF0ffa8739a03818fd18b821Ae829404B;

    uint256 public serviceFeeSlippage_ = 800000000000000000;

    function setUp() public {
        fluxFarmV2 = FluxFarmV2(deployedFluxFarm);
        // vm.startPrank(user_);
        // fluxFarm.upgradeToAndCall(address(new FluxFarm()), '');
        // vm.stopPrank();
    }

    // function test_updateFarm() public {
    //     vm.startPrank(user_);
    //     fluxFarm.updateFarm();
    //     vm.stopPrank();
    // }

    // function test_closeAllPosition() public {
    //     vm.startPrank(user_);
    //     fluxFarm.closeAllPosition(true);
    //     vm.stopPrank();
    // }

    function test_invest() public {
        vm.startPrank(user_);
        IERC20(token0).approve(address(fluxFarmV2), IERC20(token0).balanceOf(user_));
        fluxFarmV2.invest(token0, IERC20(token0).balanceOf(user_));

        IERC20(token1).approve(address(fluxFarmV2), IERC20(token1).balanceOf(user_));
        fluxFarmV2.invest(token1, IERC20(token1).balanceOf(user_));
        vm.stopPrank();
    }

    // function test_getPoolAddress() public {
    //     INonfungiblePositionManager positionManager = fluxFarm.positionManager();
    //     emit log_named_address("poolAddress", address(positionManager));
    // }
}

