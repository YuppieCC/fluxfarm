// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {FluxFarm} from "src/FluxFarm.sol";


// modify _closePosition function
contract FluxFarm_Upgrade_6Script is Script {
    FluxFarm public fluxFarm;
    
    address public deployedFluxFarmAddress = 0xEE9f31f884a24Eb6fe1aCa8aD4F53406982F3DF5;

    function run() public {
        vm.startBroadcast();

        fluxFarm = FluxFarm(deployedFluxFarmAddress);
        fluxFarm.upgradeToAndCall(address(new FluxFarm()), '');

        vm.stopBroadcast();
    }
}
