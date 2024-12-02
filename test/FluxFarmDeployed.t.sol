// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";
import {UUPSProxy} from "../src/utils/UUPSProxy.sol";
import {FluxFarm} from 'src/FluxFarm.sol';

contract FluxFarmDeployedTest is Test {
    bytes32 public constant MANAGER = bytes32(keccak256(abi.encodePacked("MANAGER")));

    FluxFarm public fluxFarm;

    address public positionManagerAddress = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address public swapRouterAddress = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public uniswapV3PoolAddress = 0xD1F1baD4c9E6c44DeC1e9bF3B94902205c5Cd6C3;
    uint256 public slippage = 50000000000000000;

    address public token0 = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607; // usdce
    address public token1 = 0xdC6fF44d5d932Cbd77B52E5612Ba0529DC6226F1; // wld

    address public user_ = 0xDE1e26F53aa97f02c06779F280A7DE56d06EbbaD;
    address public deployedFluxFarm = 0xEE9f31f884a24Eb6fe1aCa8aD4F53406982F3DF5;

    uint256 public serviceFeeSlippage_ = 800000000000000000;

    int24[][] public ticks_ = [
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
        fluxFarm = FluxFarm(deployedFluxFarm);
    }

    // function test_updateFarm() public {
    //     vm.startPrank(user_);
    //     address token_ = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    //     uint256 amount_ = 72000000;
    //     // address token = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    //     // uint256 amount = 2000000000;
    //     // fluxFarm.invest(token, amount);
    //     // fluxFarm.updateFarm();
    //     // fluxFarm.withdraw(token_, amount_);
    //     vm.stopPrank();
    // }

    function test_upgradeToAndCall() public {
        vm.startPrank(user_);
        fluxFarm.upgradeToAndCall(address(new FluxFarm()), '');
        // fluxFarm.setServiceFeeSlippage(serviceFeeSlippage_);
        // fluxFarm.closeAllPosition(false);
        // fluxFarm.setUpdateInterval(20 minutes);
        fluxFarm.updateFarm();
        uint256 token0Balance = IERC20(token0).balanceOf(address(fluxFarm));
        uint256 token1Balance = IERC20(token1).balanceOf(address(fluxFarm));
        emit log_named_uint("token0Balance: ", token0Balance);
        emit log_named_uint("token1Balance: ", token1Balance);
        vm.stopPrank();
    }

    function test_upgradeToAndCall2() public {
        vm.startPrank(user_);
        fluxFarm.upgradeToAndCall(address(new FluxFarm()), '');
        // fluxFarm.setServiceFeeSlippage(serviceFeeSlippage_);
        // fluxFarm.closeAllPosition(false);
        // fluxFarm.setUpdateInterval(20 minutes);
        fluxFarm.closeAllPosition(true);

        uint256 burnCount = fluxFarm.initialPosition(ticks_, 1e6);
        emit log_named_uint("InitialPosition tokenIds Length: ", burnCount);
        assertTrue(fluxFarm.getPositionBalance() == ticks_.length);
        vm.stopPrank();
    }
}