// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {FluxFarmV2} from "src/FluxFarmV2.sol";


contract FluxFarmV2InitialPositionScript is Script {
    FluxFarmV2 public fluxFarmV2;
    
    address public deployedFluxFarmAddress = 0xfc078b6dA7eb45a858C58cD8f66e3C6d64Cd5C3F;
    uint256 public onePositionValue_ = 1e6;

    int24[][] public ticks_ = [
        // [int24(256200), int24(258200)],
        // [int24(257200), int24(259000)],
        // [int24(258200), int24(260000)],
        // [int24(259200), int24(261000)],
        // [int24(260200), int24(262000)],
        // [int24(261000), int24(262800)],
        // [int24(262000), int24(263800)],
        // [int24(263000), int24(264800)],
        // [int24(264000), int24(265800)],
        // [int24(264800), int24(266600)],
        // [int24(265800), int24(267600)],
        // [int24(266800), int24(268600)],
        // [int24(267800), int24(269600)],
        // [int24(268600), int24(270600)],
        // [int24(269600), int24(271400)],
        // [int24(270600), int24(272400)],
        // [int24(271600), int24(273400)],
        // [int24(272400), int24(274400)],
        // [int24(273400), int24(275200)],
        // [int24(274400), int24(276200)],

        // 2025-01-11
        // [int24(264200), int24(264600)],
        // [int24(264400), int24(264800)],
        // [int24(264600), int24(265000)],
        // [int24(264800), int24(265200)],
        // [int24(265000), int24(265400)],
        // [int24(265200), int24(265600)],
        // [int24(265400), int24(265800)],
        // [int24(265600), int24(266000)],
        // [int24(265600), int24(266200)],
        // [int24(265800), int24(266400)],
        // [int24(266000), int24(266600)],
        // [int24(266200), int24(266800)],
        // [int24(266400), int24(267000)],
        // [int24(266600), int24(267200)],
        // [int24(266800), int24(267400)],
        // [int24(267000), int24(267600)],
        // [int24(267200), int24(267800)],
        // [int24(267400), int24(268000)],
        // [int24(267600), int24(268200)],
        // [int24(267800), int24(268400)],
        // [int24(268000), int24(268600)],
        // [int24(268200), int24(268800)],
        // [int24(268400), int24(269000)],
        // [int24(268600), int24(269200)],
        // [int24(268800), int24(269400)],
        // [int24(269000), int24(269600)],
        // [int24(269200), int24(269800)],
        // [int24(269400), int24(270000)],
        // [int24(269600), int24(270200)],
        // [int24(269800), int24(270400)]

        // 2025-01-30
        [int24(266000),int24(266400)],
        [int24(266200),int24(266600)],
        [int24(266400),int24(266800)],
        [int24(266600),int24(267000)],
        [int24(266800),int24(267200)],
        [int24(267000),int24(267400)],
        [int24(267200),int24(267600)],
        [int24(267400),int24(267800)],
        [int24(267600),int24(268000)],
        [int24(267800),int24(268200)],
        [int24(268000),int24(268400)],
        [int24(268200),int24(268600)],
        [int24(268400),int24(268800)],
        [int24(268600),int24(269000)],
        [int24(268800),int24(269200)],
        [int24(269000),int24(269400)],
        [int24(269200),int24(269600)],
        [int24(269400),int24(269800)],
        [int24(269600),int24(270000)],
        [int24(269800),int24(270200)],
        [int24(269800),int24(270400)],
        [int24(270000),int24(270600)],
        [int24(270200),int24(270800)],
        [int24(270400),int24(271000)],
        [int24(270600),int24(271200)],
        [int24(270800),int24(271400)],
        [int24(271000),int24(271600)],
        [int24(271200),int24(271800)],
        [int24(271400),int24(272000)],
        [int24(271600),int24(272200)]
    ];

    function run() public {
        vm.startBroadcast();

        fluxFarmV2 = FluxFarmV2(deployedFluxFarmAddress);
        fluxFarmV2.initialPosition(ticks_, onePositionValue_);

        vm.stopBroadcast();
    }
}
