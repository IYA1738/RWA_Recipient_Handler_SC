// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockDistribution {
    event Distributed(uint256 amount, address broker);

    uint256 public lastAmount;
    address public lastBroker;

    function distribute(uint256 amount, address broker) external {
        lastAmount = amount;
        lastBroker = broker;
        emit Distributed(amount, broker);
    }
}
