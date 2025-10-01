// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test_Base} from "./Test_Base.t.sol";
import {RecipientHandler} from "contracts/RecipientHandler.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Test_PermitHelper_BaseUSDC is Test_Base {
    // 构造 Quote + 卖家签名
    function _buildQuote()
        internal
        view
        returns (RecipientHandler.PriceQuote memory q, bytes memory sellerSig)
    {
        q = RecipientHandler.PriceQuote({
            quoteId: quoteId,
            paymentToken: USDC,
            seller: seller,
            price: price,
            cost: cost,
            serviceId: serviceId,
            expiry: nowTime + 1 days
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
        sellerSig = sign(quoteDigest, sellerPk);
    }

    // 构造 Order + 买家签名
    function _buildOrder()
        internal
        view
        returns (RecipientHandler.Order memory o, bytes memory buyerSig)
    {
        uint256 buyerNonce = handler.nextNonce(buyer);
        o = RecipientHandler.Order({
            buyer: buyer,
            payTo: address(handler),
            paymentToken: USDC,
            totalAmount: price,
            nonce: buyerNonce,
            quoteId: quoteId,
            serviceId: serviceId,
            deadline: nowTime + 1 hours
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
        buyerSig = sign(orderDigest, buyerPk);
    }

    function test_PermitHelper_Allowance_Ok() public {
        (RecipientHandler.PriceQuote memory q, bytes memory sSig) = _buildQuote();
        (RecipientHandler.Order memory o,  bytes memory bSig) = _buildOrder();

        vm.prank(buyer);
        handler.payWithEIP712(o, bSig, q, sSig, bytes(""), bytes(""));
    }

    function test_PermitHelper_NoAllowance_NoPermit_Reverts() public {
        (RecipientHandler.PriceQuote memory q, bytes memory sSig) = _buildQuote();
        (RecipientHandler.Order memory o,  bytes memory bSig) = _buildOrder();

        vm.startPrank(buyer);
        IERC20(USDC).approve(address(handler), 0);
        vm.expectRevert(); 
        handler.payWithEIP712(o, bSig, q, sSig, bytes(""), bytes(""));
        vm.stopPrank();
    }

    function test_PermitHelper_PseudoPermit2612_FallbackAllowance() public {
        (RecipientHandler.PriceQuote memory q, bytes memory sSig) = _buildQuote();
        (RecipientHandler.Order memory o,  bytes memory bSig) = _buildOrder();

        bytes memory fakePermit2612 = hex"01"; 

        vm.startPrank(buyer);
        IERC20(USDC).approve(address(handler), 0);
        vm.expectRevert();
        handler.payWithEIP712(o, bSig, q, sSig, fakePermit2612, bytes(""));
        vm.stopPrank();

        vm.startPrank(buyer);
        IERC20(USDC).approve(address(handler), type(uint256).max);
        handler.payWithEIP712(o, bSig, q, sSig, fakePermit2612, bytes(""));
        vm.stopPrank();
    }
}
