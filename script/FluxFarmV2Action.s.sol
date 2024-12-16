// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {FluxFarmV2} from "src/FluxFarmV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract FluxFarmV2ActionScript is Script {
    FluxFarmV2 public fluxFarmV2;
    
    address public deployedFluxFarmAddress = 0xfc078b6dA7eb45a858C58cD8f66e3C6d64Cd5C3F;
    address public token0 = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607; // usdce
    address public token1 = 0xdC6fF44d5d932Cbd77B52E5612Ba0529DC6226F1; // wld
    address public user_ = 0xDE1e26F53aa97f02c06779F280A7DE56d06EbbaD;

    function run() public {
        vm.startBroadcast();

        fluxFarmV2 = FluxFarmV2(deployedFluxFarmAddress);
        IERC20(token0).approve(deployedFluxFarmAddress, IERC20(token0).balanceOf(address(user_)));
        IERC20(token1).approve(deployedFluxFarmAddress, IERC20(token1).balanceOf(address(user_)));
        fluxFarmV2.invest(token0, IERC20(token0).balanceOf(address(user_)));
        fluxFarmV2.invest(token1, IERC20(token1).balanceOf(address(user_)));
        vm.stopBroadcast();
    }
}
