//SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import {Test_Base} from "./Test_Base.t.sol";
import {Errors} from "../contracts/libraries/Errors.sol";
import {Ownable} from "node_modules/@openzeppelin/contracts/access/Ownable.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

contract Test_AdminFunc is Test_Base ,Nonces{
    function test_setCommissionRate_ShouldSuccess_Fuzz(
        uint256 newCommissionRate
    ) public {
        vm.startPrank(owner);
        vm.assume(newCommissionRate > 0);
        vm.assume(newCommissionRate <= BPS);
        handler.setCommissionRate(newCommissionRate);
        assertEq(handler.commissionRate(), newCommissionRate);
        vm.stopPrank();
    }

    function test_setCommissionRate_ShouldRevert_Fuzz(
        uint256 newCommissionRate
    ) public {
        vm.startPrank(owner);
        vm.assume(newCommissionRate > BPS);
        vm.expectRevert(Errors.BadParas.selector);
        handler.setCommissionRate(newCommissionRate);
        vm.stopPrank();
    }

    function test_setCommissionRate_ShouldRevert_notOwner(address caller) public {
        vm.assume(caller != owner && caller != address(0));
        vm.startPrank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                caller
            )
        );
        handler.setCommissionRate(1_000);
        vm.stopPrank();
    }

    function test_setDistributionSC_ShouldSuccess(address newSC) public {
        vm.assume(newSC != address(0));
        vm.startPrank(owner);
        handler.setDistributionSC(newSC);
        assertEq(handler.distributionSC(), newSC);
        vm.stopPrank();
    }

    function test_setDistributionSC_ShouldSRevert() public {
        address newSC = address(0);
        vm.startPrank(owner);
        vm.expectRevert(Errors.ZeroAddress.selector);
        handler.setDistributionSC(newSC);
        vm.stopPrank();
    }

    function test_setDistributionSC_ShouldRevert_notOwner(
        address caller
    ) public {
        vm.assume(caller != owner && caller != address(0));
        vm.startPrank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                caller
            )
        );
        handler.setDistributionSC(address(0x123abc));
        vm.stopPrank();
    }

    function test_pause_unpause_AsOwner() public {
        vm.startPrank(owner);
        handler.pause();
        assertTrue(handler.paused());

    
        handler.unpause();
        assertFalse(handler.paused());
        vm.stopPrank();
    }

    function test_pause_ShouldRevert_NotOwner(address caller) public {
        vm.assume(caller != owner && caller != address(0));

        vm.startPrank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                caller
            )
        );
        handler.pause();
        vm.stopPrank();
    }

    function test_unpause_ShouldRevert_NotOwner(address caller) public {
        vm.assume(caller != owner && caller != address(0));

        vm.startPrank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                caller
            )
        );
        handler.unpause();
        vm.stopPrank();
    }

    function test_verifyNextNonce(address caller) public{
        vm.startPrank(caller);
        assertEq(handler.nextNonce(caller),  nonces(buyer));
        vm.stopPrank();
    }

    function test_createService_ShouldSuccess(uint128 serviceId, address _seller) public{
        vm.assume(_seller != address(0));
        vm.startPrank(owner);
        handler.createService(serviceId,_seller);
        assertEq(handler.getSeller(serviceId),_seller);
        vm.stopPrank();
    }

    function test_setServiceActive_ShouldSuccess(uint128 serviceId,address _seller) public{
        vm.assume(_seller != address(0));
        vm.startPrank(owner);
        handler.createService(serviceId,_seller);
        vm.stopPrank();
        bool setBefore = handler.checkServiceActive(serviceId);
        vm.startPrank(_seller);
        handler.setServiceActive(serviceId);
        assertEq(handler.checkServiceActive(serviceId), !setBefore);
        vm.stopPrank();
    }
}
