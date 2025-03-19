// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

import {IQuoter} from '@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol';
import {Test} from 'forge-std/Test.sol';

contract QuoterTest is Test {
    IQuoter public quoter;

    address public user_ = 0xDE1e26F53aa97f02c06779F280A7DE56d06EbbaD;
    address public deployedQuoter = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;

    address public token0 = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607; // usdce
    address public token1 = 0xdC6fF44d5d932Cbd77B52E5612Ba0529DC6226F1; // wld
    
    function setUp() public {
        quoter = IQuoter(deployedQuoter);
    }

    function test_quoteExactInputSingle() public {
        uint256 amountIn = 1e18;
        uint256 expectedAmountOut = quoter.quoteExactInputSingle(token1, token0, 10000, amountIn, 0);
        emit log_named_uint("expectedAmountOut", expectedAmountOut);
    }
}