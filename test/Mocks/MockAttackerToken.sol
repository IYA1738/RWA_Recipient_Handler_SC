//SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IRecipientHandler{
    function claim(address token, uint256 amt) external;
}

contract MockAttackerToken is ERC20{
    address public handler;
    address public victim; //seller'address
    bool public enableAttack;
    uint256 public reentranAmount;

    constructor(address _handler,  address _victim, bool _enableAttack, uint256 _reentrantAmount) ERC20("MockAttackToken","MAT"){
        handler =  _handler;
        victim = _victim;
        enableAttack = _enableAttack;
        reentranAmount =  _reentrantAmount;
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to,  uint256 amount)  external{
        _mint(to,amount);
    }

    function setReentrancy(bool enable,  uint256 amount) external{
        enableAttack  =  enable;
        reentranAmount = amount;
    }

    function transfer(address to, uint256 amount) public override returns(bool){
        bool ok =  super.transfer(to,amount);
        if(enableAttack &&  msg.sender == handler && to == victim  && reentranAmount > 0){
            IRecipientHandler(handler).claim(address(this),reentranAmount);
        }
        return ok;
    }
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        bool ok = super.transferFrom(from, to, amount);
        if (enableAttack && msg.sender == handler && to == victim && reentranAmount > 0) {
            IRecipientHandler(handler).claim(address(this), reentranAmount);
        }
        return ok;
    }
}   