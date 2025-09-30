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
        vm.assume(newCommissionRate > 0);
        vm.assume(newCommissionRate <= BPS);
        sc.setCommissionRate(newCommissionRate);
        assertEq(sc.commissionRate(), newCommissionRate);
    }

    function test_setSellerRate_ShouldRevert_Fuzz(
        uint256 newCommissionRate
    ) public {
        vm.startPrank(owner);
        vm.assume(newCommissionRate >= BPS);
        vm.expectRevert(Errors.BadParas.selector);
        sc.setCommissionRate(newCommissionRate);
        vm.stopPrank();
    }

    function test_setSellerRate_ShouldRevert_notOwner(address caller) public {
        vm.assume(caller != owner && caller != address(0));
        vm.startPrank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                caller
            )
        );
        sc.setCommissionRate(1_000);
        vm.stopPrank();
    }

    function test_setDistributionSC_ShouldSuccess(address newSC) public {
        vm.assume(newSC != address(0));
        vm.startPrank(owner);
        sc.setDistributionSC(newSC);
        assertEq(sc.distributionSC(), newSC);
        vm.stopPrank();
    }

    function test_setDistributionSC_ShouldSRevert() public {
        address newSC = address(0);
        vm.startPrank(owner);
        vm.expectRevert(Errors.ZeroAddress.selector);
        sc.setDistributionSC(newSC);
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
        sc.setDistributionSC(address(0x123abc));
        vm.stopPrank();
    }

    function test_pause_unpause_AsOwner() public {
        vm.startPrank(owner);
        sc.pause();
        assertTrue(sc.paused());

    
        sc.unpause();
        assertFalse(sc.paused());
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
        sc.pause();
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
        sc.unpause();
        vm.stopPrank();
    }

    function test_verifyNextNonce(address caller) public{
        vm.startPrank(caller);
        assertEq(sc.nextNonce(caller),  nonces(user));
        vm.stopPrank();
    }
}
