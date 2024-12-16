// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";
import {UUPSProxy} from "../src/utils/UUPSProxy.sol";
import {FluxFarmV2} from 'src/FluxFarmV2.sol';

contract FluxFarmV2Test is Test {
    bytes32 public constant MANAGER = bytes32(keccak256(abi.encodePacked("MANAGER")));

    FluxFarmV2 public fluxFarmV2;

    address public positionManagerAddress = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address public swapRouterAddress = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public uniswapV3PoolAddress = 0xD1F1baD4c9E6c44DeC1e9bF3B94902205c5Cd6C3;
    uint256 public slippage = 1e18;

    address public token0 = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607; // usdce
    address public token1 = 0xdC6fF44d5d932Cbd77B52E5612Ba0529DC6226F1; // wld

    address public token0_oracle = 0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3;  // usdce-usd
    address public token1_oracle = 0x4e1C6B168DCFD7758bC2Ab9d2865f1895813D236;  // wld-usd

    address public user_ = 0xDE1e26F53aa97f02c06779F280A7DE56d06EbbaD;
    address public wldHolder = 0x1bc40dbd66579e4202e3cE2A4f49a71Ed2c8C138;
    address public usdceHolder = 0x4a84675512949f81EBFEAAcC6C00D03eDd329de5;

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
        fluxFarmV2 = FluxFarmV2(
            address(new UUPSProxy(
                address(new FluxFarmV2()), '')
            )
        );

        fluxFarmV2.initialize(
            uniswapV3PoolAddress,
            positionManagerAddress,
            swapRouterAddress,
            token0,
            token1,
            token0_oracle,
            token1_oracle
        );
        fluxFarmV2.setUpdateInterval(15 minutes);
        fluxFarmV2.setserviceFeeFactor(1e18);
        fluxFarmV2.setSlippage(slippage);
        vm.stopPrank();

        vm.startPrank(usdceHolder);
        IERC20(token0).transfer(address(fluxFarmV2), IERC20(token0).balanceOf(usdceHolder));
        vm.stopPrank();
        vm.startPrank(wldHolder);
        IERC20(token1).transfer(address(fluxFarmV2), IERC20(token1).balanceOf(wldHolder));
        vm.stopPrank();

        vm.startPrank(user_);
        uint256 burnCount = fluxFarmV2.initialPosition(ticks_, 1e6);
        emit log_named_uint("InitialPosition tokenIds Length: ", burnCount);
        assertTrue(fluxFarmV2.getPositionBalance() == ticks_.length);
        vm.stopPrank();
    }

    // function test_updateFarm() public {
    //     vm.startPrank(user_);
    //     fluxFarmV2.updateFarm();
    //     vm.stopPrank();
    // }

    // function test_harvestInfo() public {
    //     vm.startPrank(user_);
    //     fluxFarmV2.updateFarm();
    //     vm.stopPrank();

    //     uint256 latestInvestId = fluxFarmV2.latestInvestID();
    //     (
    //         uint256 investID,
    //         uint256 startTimestamp,
    //         uint256 endTimestamp,
    //         uint256 tokenId,
    //         uint256 liquidity,
    //         uint256 totalFees0,
    //         uint256 totalFees1
    //     ) = fluxFarmV2.harvestInfo(latestInvestId);
    //     emit log_named_uint("latestInvestId: ", latestInvestId);
    //     emit log_named_uint("investID: ", investID);
    //     emit log_named_uint("startTimestamp: ", startTimestamp);
    //     emit log_named_uint("endTimestamp: ", endTimestamp);
    //     emit log_named_uint("tokenId: ", tokenId);
    //     emit log_named_uint("liquidity: ", liquidity);
    //     emit log_named_uint("totalFees0: ", totalFees0);
    //     emit log_named_uint("totalFees1: ", totalFees1);
    // }

    function test_investAndWithdraw() public {
        vm.startPrank(user_);
        // IERC20(token0).approve(address(fluxFarmV2), IERC20(token0).balanceOf(user_));
        // fluxFarmV2.invest(token0, IERC20(token0).balanceOf(user_));

        IERC20(token1).approve(address(fluxFarmV2), IERC20(token1).balanceOf(user_));
        fluxFarmV2.invest(token1, IERC20(token1).balanceOf(user_));
        vm.stopPrank();

        uint256 totalInvest = fluxFarmV2.totalInvest();
        emit log_named_uint("totalInvest: ", totalInvest);

        vm.startPrank(user_);
        // fluxFarmV2.withdraw(token0, fluxFarmV2.tokenInvest(token0));
        fluxFarmV2.withdraw(token1, fluxFarmV2.tokenInvest(token1));
        vm.stopPrank();

        uint256 totalWithdraw = fluxFarmV2.totalWithdraw();
        emit log_named_uint("totalWithdraw: ", totalWithdraw);
    }
}
