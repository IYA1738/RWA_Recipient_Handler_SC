// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test_Base} from "./Test_Base.t.sol";
import {MockAttackerToken} from "test/Mocks/MockAttackerToken.sol";
import {RecipientHandler} from "contracts/RecipientHandler.sol";

contract Test_Reentrancy is Test_Base{
    uint256 public constant DECIMALS= 6;
    function test_Claim_Reentrancy_ShouldRevert() public{
        MockAttackerToken atk = new MockAttackerToken(address(handler),seller,false, 100  * (10 ** DECIMALS));
        atk.mint(buyer, 100_000 * (10 ** DECIMALS));
        vm.prank(buyer);
        atk.approve(address(handler),type(uint256).max);
         RecipientHandler.PriceQuote memory q = RecipientHandler.PriceQuote({
            quoteId: quoteId,
            paymentToken: address(atk),
            seller: seller,
            price: price,
            cost: cost,
            serviceId: serviceId,
            expiry: uint64(block.timestamp + 1 days)
        });

        bytes32 quoteStruct = keccak256(abi.encode(
            PRICEQUOTE_TYPEHASH,
            q.quoteId,
            q.paymentToken,
            q.seller,
            q.price,
            q.cost,
            q.serviceId,
            q.expiry
        ));
        bytes32 quoteDigest = hashTyped(quoteStruct);
        bytes memory sellerSig = sign(quoteDigest, sellerPk);

        // Order
        uint256 buyerNonce = handler.nextNonce(buyer);
        RecipientHandler.Order memory o = RecipientHandler.Order({
            buyer: buyer,
            payTo: address(handler),
            paymentToken: address(atk),
            totalAmount: price,
            nonce: buyerNonce,
            quoteId: quoteId,
            serviceId: serviceId,
            deadline: uint64(block.timestamp + 1 hours)
        });

        bytes32 orderStruct = keccak256(abi.encode(
            ORDER_TYPEHASH,
            o.buyer, o.payTo, o.paymentToken, o.totalAmount, o.nonce, o.quoteId, o.serviceId, o.deadline
        ));
        bytes32 orderDigest = hashTyped(orderStruct);
        bytes memory buyerSig = sign(orderDigest, buyerPk);

        vm.prank(buyer);
        handler.payWithEIP712(o, buyerSig, q, sellerSig, bytes(""), bytes(""));

        uint256 profit = handler.getProfit(seller, address(atk));
        assertGt(profit, 0);

        atk.setReentrancy(true, 100 * (10 ** DECIMALS));
        vm.prank(seller);
        vm.expectRevert(bytes("Locked"));
        handler.claim(address(atk), 1 * (10 ** DECIMALS));
    }
}