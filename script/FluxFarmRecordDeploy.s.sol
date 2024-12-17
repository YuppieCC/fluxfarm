// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {UUPSProxy} from "src/utils/UUPSProxy.sol";
import {FluxFarmRecord} from "src/FluxFarmRecord.sol";

contract FluxFarmRecordDeployScript is Script {
    FluxFarmRecord public fluxFarmRecord;
    
    address public uniswapV3Pool = 0xD1F1baD4c9E6c44DeC1e9bF3B94902205c5Cd6C3;
    address public deployedFluxFarm = 0xfc078b6dA7eb45a858C58cD8f66e3C6d64Cd5C3F;
    address public nonfungiblePositionManager = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    function run() public {
        vm.startBroadcast();

       fluxFarmRecord = FluxFarmRecord(
            address(new UUPSProxy(
                address(new FluxFarmRecord()), '')
            )
        );

        fluxFarmRecord.initialize();
        fluxFarmRecord.setDeployedFluxFarmAddress(deployedFluxFarm);
        fluxFarmRecord.setUniswapV3Pool(uniswapV3Pool);
        fluxFarmRecord.setNonfungiblePositionManager(nonfungiblePositionManager);
        fluxFarmRecord.setKeeperInterval(4 hours);

        vm.stopBroadcast();
    }
}
