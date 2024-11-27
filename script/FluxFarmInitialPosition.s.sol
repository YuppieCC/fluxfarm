// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {FluxFarm} from "src/FluxFarm.sol";


contract FluxFarmInitialPositionScript is Script {
    FluxFarm public fluxFarm;
    
    address public deployedFluxFarmAddress = 0xEE9f31f884a24Eb6fe1aCa8aD4F53406982F3DF5;
    uint256 public onePositionValue_ = 1e16;  // 2 usdce + 2 wld  * 2.385 = 6.77 usd
    int24[][] public ticks_ = [
        [int24(256800), int24(258600)],
        [int24(257800), int24(259600)],
        [int24(258800), int24(260600)],
        [int24(259600), int24(261400)],
        [int24(260600), int24(262400)],
        [int24(261600), int24(263400)],
        [int24(262600), int24(264400)],
        [int24(263400), int24(265200)],
        [int24(264400), int24(266200)],
        [int24(265400), int24(267200)],
        [int24(266400), int24(268200)],
        [int24(267200), int24(269200)],
        [int24(268200), int24(270000)],
        [int24(269200), int24(271000)],
        [int24(270200), int24(272000)],
        [int24(271200), int24(273000)],
        [int24(272000), int24(273800)],
        [int24(273000), int24(274800)],
        [int24(274000), int24(275800)],
        [int24(275000), int24(276800)]
    ];

    function run() public {
        vm.startBroadcast();

        fluxFarm = FluxFarm(deployedFluxFarmAddress);
        fluxFarm.initialPosition(ticks_, onePositionValue_);

        vm.stopBroadcast();
    }
}
