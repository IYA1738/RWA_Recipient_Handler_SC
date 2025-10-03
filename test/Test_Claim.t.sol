//SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;
import {Test_Base} from "./Test_Base.t.sol";
import {MockDistribution} from "test/Mocks/MockDistribution.sol";
import {RecipientHandler} from "contracts/RecipientHandler.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Test_Claim is Test_Base{
    
    // Helper function to create a valid order and execute payment
    function executeValidPayment() internal returns (uint256 sellerProfit) {
        RecipientHandler.Order memory order = RecipientHandler.Order({
            buyer: buyer,
            payTo: address(handler),
            paymentToken: USDC,
            totalAmount: price,
            nonce: handler.nextNonce(buyer),
            quoteId: quoteId,
            serviceId: serviceId,
            deadline: nowTime + 1 hours
        });

        RecipientHandler.PriceQuote memory quote = RecipientHandler.PriceQuote({
            quoteId: quoteId,
            paymentToken: USDC,
            seller: seller,
            price: price,
            cost: cost,
            serviceId: serviceId,
            expiry: nowTime + 1 hours
        });

        bytes32 orderDigest = hashTyped(
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH,
                    order.buyer,
                    order.payTo,
                    order.paymentToken,
                    order.totalAmount,
                    order.nonce,
                    order.quoteId,
                    order.serviceId,
                    order.deadline
                )
            )
        );

        bytes32 quoteDigest = hashTyped(
            keccak256(
                abi.encode(
                    PRICEQUOTE_TYPEHASH,
                    quote.quoteId,
                    quote.paymentToken,
                    quote.seller,
                    quote.price,
                    quote.cost,
                    quote.serviceId,
                    quote.expiry
                )
            )
        );

        bytes memory buyerSig = sign(orderDigest, buyerPk);
        bytes memory sellerQuoteSig = sign(quoteDigest, sellerPk);

        vm.prank(buyer);
        handler.payWithEIP712(
            order,
            buyerSig,
            quote,
            sellerQuoteSig,
            "",
            ""
        );

        // Calculate expected seller profit
        uint256 netProfit = price - cost;
        uint256 commission = (netProfit * commissionRate) / BPS;
        sellerProfit = price - commission;
    }



    function test_Claim_Success() public {
        uint256 expectedProfit = executeValidPayment();
        
        uint256 sellerBalanceBefore = IERC20(USDC).balanceOf(seller);
        uint256 handlerBalanceBefore = IERC20(USDC).balanceOf(address(handler));
        
        vm.prank(seller);
        vm.expectEmit(true, true, false, true);
        emit RecipientHandler.SellerClaimed(seller, USDC, expectedProfit);
        handler.claim(USDC, expectedProfit);
        
        uint256 sellerBalanceAfter = IERC20(USDC).balanceOf(seller);
        uint256 handlerBalanceAfter = IERC20(USDC).balanceOf(address(handler));
        
        assertEq(sellerBalanceAfter - sellerBalanceBefore, expectedProfit, "Seller should receive correct amount");
        assertEq(handlerBalanceBefore - handlerBalanceAfter, expectedProfit, "Handler balance should decrease");
        assertEq(handler.getProfit(seller, USDC), 0, "Seller profit should be zero after claim");
    }

    function test_Claim_PartialClaim() public {
        uint256 totalProfit = executeValidPayment();
        uint256 partialAmount = totalProfit / 2;
        
        vm.prank(seller);
        handler.claim(USDC, partialAmount);
        
        assertEq(handler.getProfit(seller, USDC), totalProfit - partialAmount, "Remaining profit should be correct");
        
        // Claim the rest
        vm.prank(seller);
        handler.claim(USDC, totalProfit - partialAmount);
        
        assertEq(handler.getProfit(seller, USDC), 0, "All profit should be claimed");
    }

    function test_Claim_MultipleClaims() public {
        // Execute multiple payments
        executeValidPayment();
        
        quoteId = keccak256("q-2");
        executeValidPayment();
        
        quoteId = keccak256("q-3");
        uint256 expectedProfit = executeValidPayment();
        
        uint256 totalProfit = handler.getProfit(seller, USDC);
        assertEq(totalProfit, expectedProfit * 3, "Total profit should be sum of all payments");
        
        vm.prank(seller);
        handler.claim(USDC, totalProfit);
        
        assertEq(handler.getProfit(seller, USDC), 0, "All profit should be claimed");
    }

    function test_Claim_RevertZeroAddress() public {
        executeValidPayment();
        
        vm.prank(seller);
        vm.expectRevert();
        handler.claim(address(0), 100e6);
    }

    function test_Claim_RevertZeroAmount() public {
        executeValidPayment();
        
        vm.prank(seller);
        vm.expectRevert();
        handler.claim(USDC, 0);
    }

    function test_Claim_RevertInsufficientBalance() public {
        uint256 profit = executeValidPayment();
        
        vm.prank(seller);
        vm.expectRevert();
        handler.claim(USDC, profit + 1);
    }

    function test_Claim_RevertNoProfit() public {
        vm.prank(seller);
        vm.expectRevert();
        handler.claim(USDC, 1e6);
    }

    function test_Claim_DifferentSellers() public {
        // First seller payment
        uint256 profit1 = executeValidPayment();
        
        // Create second seller
        uint256 seller2Pk = 789;
        address seller2 = vm.addr(seller2Pk);
        uint128 serviceId2 = 1002;
        
        vm.prank(owner);
        handler.createService(serviceId2, seller2);
        
        vm.prank(seller2);
        handler.setServiceActive(serviceId2);
        
        // Second seller payment
        RecipientHandler.Order memory order = RecipientHandler.Order({
            buyer: buyer,
            payTo: address(handler),
            paymentToken: USDC,
            totalAmount: price,
            nonce: handler.nextNonce(buyer),
            quoteId: keccak256("q-seller2"),
            serviceId: serviceId2,
            deadline: nowTime + 1 hours
        });

        RecipientHandler.PriceQuote memory quote = RecipientHandler.PriceQuote({
            quoteId: keccak256("q-seller2"),
            paymentToken: USDC,
            seller: seller2,
            price: price,
            cost: cost,
            serviceId: serviceId2,
            expiry: nowTime + 1 hours
        });

        bytes32 orderDigest = hashTyped(
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH,
                    order.buyer,
                    order.payTo,
                    order.paymentToken,
                    order.totalAmount,
                    order.nonce,
                    order.quoteId,
                    order.serviceId,
                    order.deadline
                )
            )
        );

        bytes32 quoteDigest = hashTyped(
            keccak256(
                abi.encode(
                    PRICEQUOTE_TYPEHASH,
                    quote.quoteId,
                    quote.paymentToken,
                    quote.seller,
                    quote.price,
                    quote.cost,
                    quote.serviceId,
                    quote.expiry
                )
            )
        );

        bytes memory buyerSig = sign(orderDigest, buyerPk);
        bytes memory seller2QuoteSig = sign(quoteDigest, seller2Pk);

        vm.prank(buyer);
        handler.payWithEIP712(order, buyerSig, quote, seller2QuoteSig, "", "");
        
        // Both sellers claim
        vm.prank(seller);
        handler.claim(USDC, profit1);
        
        vm.prank(seller2);
        handler.claim(USDC, profit1);
        
        assertEq(handler.getProfit(seller, USDC), 0);
        assertEq(handler.getProfit(seller2, USDC), 0);
    }
    
}

