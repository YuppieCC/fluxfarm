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

    address public user_ = 0xDE1e26F53aa97f02c06779F280A7DE56d06EbbaD;
    address public deployedFluxFarm = 0xEE9f31f884a24Eb6fe1aCa8aD4F53406982F3DF5;

    uint256 public serviceFeeSlippage_ = 800000000000000000;

    function setUp() public {
        fluxFarm = FluxFarm(deployedFluxFarm);
    }

    function test_updateFarm() public {
        vm.startPrank(user_);
        address token_ = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
        uint256 amount_ = 72000000;
        // address token = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
        // uint256 amount = 2000000000;
        // fluxFarm.invest(token, amount);
        // fluxFarm.updateFarm();
        fluxFarm.withdraw(token_, amount_);
        vm.stopPrank();
    }

    function test_upgradeToAndCall() public {
        vm.startPrank(user_);
        fluxFarm.upgradeToAndCall(address(new FluxFarm()), '');
        fluxFarm.setServiceFeeSlippage(serviceFeeSlippage_);
        fluxFarm.closeAllPosition(false);
        vm.stopPrank();
    }
}