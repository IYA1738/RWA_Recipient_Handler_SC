//SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;
import {Test} from "lib/forge-std/src/Test.sol";
import {RecipientHandler} from "../contracts/RecipientHandler.sol";

contract Test_Base is Test{
    address public owner = address(0x123);
    address public user = address(0xabc);
    RecipientHandler sc;
    uint256 public constant BPS = 10_000;
    function setUp() public virtual{
        vm.startPrank(owner);
        sc = new RecipientHandler("Test","1", address(0xdef), 9_000);
    }
}