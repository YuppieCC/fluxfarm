// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {UUPSProxy} from "src/utils/UUPSProxy.sol";
import {FluxFarmV2} from "src/FluxFarmV2.sol";

contract FluxFarmV2DeployScript is Script {
    FluxFarmV2 public fluxFarmV2;

    address public positionManagerAddress = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address public swapRouterAddress = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public uniswapV3PoolAddress = 0xD1F1baD4c9E6c44DeC1e9bF3B94902205c5Cd6C3;

    address public token0 = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607; // usdce
    address public token1 = 0xdC6fF44d5d932Cbd77B52E5612Ba0529DC6226F1; // wld
    address public token0_oracle = 0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3;  // usdce-usd
    address public token1_oracle = 0x4e1C6B168DCFD7758bC2Ab9d2865f1895813D236;  // wld-usd

    uint256 public updateInterval = 1 weeks;
    uint256 public slippage = 100000000000000000;
    uint256 public serviceFeeFactor = 800000000000000000;

    function run() public {
        vm.startBroadcast();

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

        fluxFarmV2.setUpdateInterval(updateInterval);
        fluxFarmV2.setserviceFeeFactor(serviceFeeFactor);
        fluxFarmV2.setSlippage(slippage);

        vm.stopBroadcast();
    }
}
