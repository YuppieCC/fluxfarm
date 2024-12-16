// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {FluxFarm} from "src/FluxFarm.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract FluxFarmShoutdownScript is Script {
    FluxFarm public fluxFarm;
    
    address public deployedFluxFarmAddress = 0xEE9f31f884a24Eb6fe1aCa8aD4F53406982F3DF5;
    address public token0 = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607; // usdce
    address public token1 = 0xdC6fF44d5d932Cbd77B52E5612Ba0529DC6226F1; // wld
    address public receiver = 0xDE1e26F53aa97f02c06779F280A7DE56d06EbbaD;
   
    function run() public {
        vm.startBroadcast();

        fluxFarm = FluxFarm(deployedFluxFarmAddress);
        fluxFarm.claimTokens(token0, receiver, IERC20(token0).balanceOf(deployedFluxFarmAddress));
        fluxFarm.claimTokens(token1, receiver, IERC20(token1).balanceOf(deployedFluxFarmAddress));
        
        vm.stopBroadcast();
    }
}
