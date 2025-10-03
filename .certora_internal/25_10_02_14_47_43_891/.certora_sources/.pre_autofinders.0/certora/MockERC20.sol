// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockERC20 {
    string public name = "MockERC20";
    string public symbol = "MCK";
    uint8  public decimals = 6; //Mock USDC, so sync decimals

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function setBalance(address a, uint256 v) external { balanceOf[a] = v; }
    function setAllowance(address owner, address spender, uint256 v) external { allowance[owner][spender] = v; }

    function approve(address spender, uint256 v) external returns (bool) {
        allowance[msg.sender][spender] = v; return true;
    }

    function transferFrom(address from, address to, uint256 v) external returns (bool) {
        require(to != address(0), "to=0");
        require(balanceOf[from] >= v, "bal");
        uint256 allw = allowance[from][msg.sender];
        if (allw != type(uint256).max) {
            require(allw >= v, "allow");
            allowance[from][msg.sender] = allw - v;
        }
        balanceOf[from] -= v;
        balanceOf[to]   += v;
        return true;
    }

    function transfer(address to, uint256 v) external returns (bool) {
        require(to != address(0), "to=0");
        require(balanceOf[msg.sender] >= v, "bal");
        balanceOf[msg.sender] -= v;
        balanceOf[to] += v;
        return true;
    }
}
