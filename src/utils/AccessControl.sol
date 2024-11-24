// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";


abstract contract AccessControl is AccessControlUpgradeable {
    // safe administrator
    bytes32 public constant SAFE_ADMIN = bytes32(keccak256(abi.encodePacked("SAFE_ADMIN")));

    // manager
    bytes32 public constant MANAGER = bytes32(keccak256(abi.encodePacked("MANAGER")));

}
