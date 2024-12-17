// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {FluxFarmV2} from "src/FluxFarmV2.sol";


contract FluxFarmV2_Upgrade_1Script is Script {
    FluxFarmV2 public fluxFarmV2;
    
    address public deployedFluxFarmAddress = 0xfc078b6dA7eb45a858C58cD8f66e3C6d64Cd5C3F;

    function run() public {
        vm.startBroadcast();

        fluxFarmV2 = FluxFarmV2(deployedFluxFarmAddress);
        fluxFarmV2.upgradeToAndCall(address(new FluxFarmV2()), '');

        vm.stopBroadcast();
    }
}
