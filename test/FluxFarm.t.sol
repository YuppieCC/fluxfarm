// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";
import {UUPSProxy} from "../src/utils/UUPSProxy.sol";
import {FluxFarm} from 'src/FluxFarm.sol';

contract FluxFarmTest is Test {
    bytes32 public constant MANAGER = bytes32(keccak256(abi.encodePacked("MANAGER")));

    FluxFarm public fluxFarm;

    address public positionManagerAddress = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address public swapRouterAddress = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public uniswapV3PoolAddress = 0xD1F1baD4c9E6c44DeC1e9bF3B94902205c5Cd6C3;
    uint256 public slippage = 50000000000000000;

    address public token0 = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607; // usdce
    address public token1 = 0xdC6fF44d5d932Cbd77B52E5612Ba0529DC6226F1; // wld

    address public token0_oracle = 0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3;  // usdce-usd
    address public token1_oracle = 0x4e1C6B168DCFD7758bC2Ab9d2865f1895813D236;  // wld-usd

    address public user_ = 0xDE1e26F53aa97f02c06779F280A7DE56d06EbbaD;

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
        vm.startPrank(user_);
        fluxFarm = FluxFarm(
            address(new UUPSProxy(
                address(new FluxFarm()), '')
            )
        );

        fluxFarm.initialize(
            uniswapV3PoolAddress,
            positionManagerAddress,
            swapRouterAddress,
            token0,
            token1,
            token0_oracle,
            token1_oracle,
            slippage
        );

        IERC20(token0).transfer(address(fluxFarm), 2e6);
        IERC20(token1).transfer(address(fluxFarm), 2e18);
        uint256 burnCount = fluxFarm.initialPosition(ticks_, 1e16);
        emit log_named_uint("InitialPosition tokenIds Length: ", burnCount);
        assertTrue(fluxFarm.getPositionBalance() == ticks_.length);
        vm.stopPrank();
    }

    function test_addAsset() public {
        vm.startPrank(user_);
        uint256 addToken0Amount = 2e6;
        uint256 addToken1Amount = 2e18;

        IERC20(token0).approve(address(fluxFarm), addToken0Amount);
        fluxFarm.invest(token0, addToken0Amount);
        assertTrue(fluxFarm.getPositionBalance() == ticks_.length);
        vm.warp(block.timestamp + 30 minutes);

        IERC20(token1).approve(address(fluxFarm), addToken1Amount);
        fluxFarm.invest(token1, addToken1Amount);
        assertTrue(fluxFarm.getPositionBalance() == ticks_.length);

        vm.stopPrank();
    }

    function test_getAmountOutMin() public {
        uint256 amount1OutMin = fluxFarm.getAmountOutMin(token0, token1, 1e6);
        emit log_named_uint("amount1OutMin: ", amount1OutMin);

        uint256 amount0OutMin = fluxFarm.getAmountOutMin(token1, token0, 1e18);
        emit log_named_uint("amount0OutMin: ", amount0OutMin);
    }

    function test_closeAllPosition() public {
        vm.startPrank(user_);

        uint256 addToken0Amount = 2e6;
        uint256 addToken1Amount = 2e18;
        IERC20(token0).approve(address(fluxFarm), addToken0Amount);
        IERC20(token1).approve(address(fluxFarm), addToken1Amount);
        fluxFarm.invest(token0, addToken0Amount);
        fluxFarm.invest(token1, addToken1Amount);

        vm.warp(block.timestamp + 180 minutes);
        (
            uint256 burnCount,
            uint256 totalAmount0,
            uint256 totalAmount1,
            uint256 totalFees0,
            uint256 totalFees1,
            uint256 nowBalanceToken0,
            uint256 nowBalanceToken1
        ) = fluxFarm.closeAllPosition(true);
        assertTrue(burnCount == ticks_.length);

        emit log_named_uint("burnCount: ", burnCount);
        emit log_named_uint("totalAmount0: ", totalAmount0);
        emit log_named_uint("totalAmount1: ", totalAmount1);
        emit log_named_uint("totalFees0: ", totalFees0);
        emit log_named_uint("totalFees1: ", totalFees1);
        emit log_named_uint("nowBalanceToken0: ", nowBalanceToken0);
        emit log_named_uint("nowBalanceToken1: ", nowBalanceToken1);
        vm.stopPrank();
    }
}
