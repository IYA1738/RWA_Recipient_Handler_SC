//SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import {Test_Base} from "./Test_Base.t.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {MockDistribution} from "test/Mocks/MockDistribution.sol";
import {RecipientHandler} from "contracts/RecipientHandler.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "contracts/libraries/Errors.sol";

contract Test_Revoke is Test_Base {
    
    function test_Revoke_ShouldSuccess() public {
        
        //Quote
        RecipientHandler.PriceQuote memory q = RecipientHandler.PriceQuote({
            quoteId: quoteId,
            paymentToken: USDC,
            seller: seller,
            price: price,
            cost: cost,
            serviceId: serviceId,
            expiry: nowTime + 365 days
        });
        bytes32 quoteStruct = keccak256(
            abi.encode(
                PRICEQUOTE_TYPEHASH,
                q.quoteId,
                q.paymentToken,
                q.seller,
                q.price,
                q.cost,
                q.serviceId,
                q.expiry
            )
        );
        bytes32 quoteDigest = hashTyped(quoteStruct);
        bytes memory sellerSig = sign(quoteDigest, sellerPk);

        // Order
        uint256 buyerNonce = handler.nextNonce(buyer);
        RecipientHandler.Order memory o = RecipientHandler.Order({
            buyer: buyer,
            payTo: address(handler),
            paymentToken: USDC,
            totalAmount: price,
            nonce: buyerNonce,
            quoteId: quoteId,
            serviceId: serviceId,
            deadline: nowTime + 1 days
        });

        bytes32 orderStruct = keccak256(
            abi.encode(
                ORDER_TYPEHASH,
                o.buyer,
                o.payTo,
                o.paymentToken,
                o.totalAmount,
                o.nonce,
                o.quoteId,
                o.serviceId,
                o.deadline
            )
        );
        bytes32 orderDigest = hashTyped(orderStruct);
        bytes memory buyerSig = sign(orderDigest, buyerPk);
        
        vm.prank(seller);
        handler.revokeQuote(q,sellerSig);
        vm.startPrank(buyer);
        vm.expectRevert(Errors.QuoteRevoked.selector);
        handler.payWithEIP712(
            o,
            buyerSig,
            q,
            sellerSig,
            bytes(""), // permit2612
            bytes("") // permit2
        );
        vm.stopPrank();
    }
}
