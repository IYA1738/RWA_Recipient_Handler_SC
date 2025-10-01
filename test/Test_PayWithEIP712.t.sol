//SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import {Test_Base} from "./Test_Base.t.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {MockDistribution} from "test/Mocks/MockDistribution.sol";
import {RecipientHandler} from "contracts/RecipientHandler.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "contracts/libraries/Errors.sol";

contract Test_PayWithEIP712 is Test, Nonces {
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    uint256 buyerPk = 0xB0B;
    uint256 sellerPk = 0xC0C;
    address buyer;
    address seller;

    string constant NAME = "Test";
    string constant VERSION = "1";

    uint128 serviceId = 1001;
    uint256 commissionRate = 1000; // 10%
    uint256 price = 1_000e6; // 1000 USDC
    uint256 cost = 100e6; // 100  USDC

    bytes32 quoteId;
    uint64 nowTime;

    uint256 forkId;

    MockDistribution distribution;
    RecipientHandler handler;

    function setUp() public {
        forkId = vm.createSelectFork(
            "https://base-mainnet.infura.io/v3/c8b8880b688449e098c268f568bf7700"
        );
        //Generate address
        buyer = vm.addr(buyerPk);
        seller = vm.addr(sellerPk);

        distribution = new MockDistribution();
        handler = new RecipientHandler(
            "Test",
            "1",
            address(distribution),
            1_000
        );
        handler.createService(serviceId, seller);
        vm.prank(seller);
        handler.setServiceActive(serviceId);
        deal(USDC, buyer, 100_000e6);
        deal(USDC, address(handler), 100_000e6);
        vm.startPrank(buyer);
        IERC20(USDC).approve(address(handler), type(uint256).max);
        vm.stopPrank();
        vm.deal(buyer, 100 ether);
        vm.deal(seller, 100 ether);

        nowTime = uint64(block.timestamp);
        quoteId = keccak256("q-1");
    }

    // typehash
    bytes32 constant ORDER_TYPEHASH =
        keccak256(
            "Order(address buyer, address payTo,address paymentToken, uint256 totalAmount, uint256 nonce,bytes32 quoteId, uint128 serviceId, uint64 deadline)"
        );
    bytes32 constant PRICEQUOTE_TYPEHASH =
        keccak256(
            "PriceQuote(bytes32 quoteId,address paymentToken,address seller,uint256 price,uint256 cost,uint128 serviceId,uint64 expiry)"
        );

    bytes32 constant EIP712_DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version, uint256 chainId, address verifyingContract)"
        );

    function domainSeparatorLocal() internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN_TYPEHASH,
                    keccak256(bytes("Test")),
                    keccak256(bytes("1")),
                    8453, //Base mainnet
                    address(handler)
                )
            );
    }

    function hashTyped(bytes32 structHash) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19\x01", domainSeparatorLocal(), structHash)
            );
    }

    function sign(
        bytes32 digest,
        uint256 pk
    ) internal pure returns (bytes memory sig) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        sig = abi.encodePacked(r, s, v);
    }

    function test_payWithEIP712_USDC_DistributionMock() public {
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

        uint256 buyerBefore = IERC20(USDC).balanceOf(buyer);
        uint256 scBefore = IERC20(USDC).balanceOf(address(handler));

        uint256 netProfit = price - cost;
        uint256 commission = Math.mulDiv(netProfit, commissionRate, 10_000);
        uint256 sellerProfit = o.totalAmount - commission;

        vm.startPrank(buyer);
        handler.payWithEIP712(
            o,
            buyerSig,
            q,
            sellerSig,
            bytes(""), // permit2612
            bytes("") // permit2
        );
        vm.stopPrank();

        // handler
        assertEq(
            IERC20(USDC).balanceOf(buyer),
            buyerBefore - price,
            "buyer USDC not deducted"
        );
        assertEq(
            IERC20(USDC).balanceOf(address(handler)),
            scBefore + price - commission,
            "handler holds sellerProfit"
        );

        // MockDistribution
        assertEq(distribution.lastAmount(), commission, "commission mismatch");
        assertEq(
            distribution.lastBroker(),
            address(0),
            "broker should be zero"
        );

        //the test will be replace later
        //then use mapping to calculate amount of claim
        uint256 handlerUSDCBeforeClaim = IERC20(USDC).balanceOf(
            address(handler)
        );
        vm.prank(seller);
        handler.claim(USDC, sellerProfit);
        assertEq(
            IERC20(USDC).balanceOf(seller),
            sellerProfit,
            "seller did not receive profit"
        );
        assertEq(
            IERC20(USDC).balanceOf(address(handler)),
            handlerUSDCBeforeClaim - sellerProfit,
            "handler did not pay seller"
        );
    }

    function test_payWithEIP712_RevertWith_BuyerSigExpired() public {
        vm.startPrank(buyer);
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

        RecipientHandler.PriceQuote memory q = RecipientHandler.PriceQuote({
            quoteId: quoteId,
            paymentToken: USDC,
            seller: seller,
            price: price,
            cost: cost,
            serviceId: serviceId,
            expiry: nowTime + 365 days
        });
        vm.warp(nowTime + 2 days); //Expired
        vm.expectRevert(Errors.SigExpired.selector);
        handler.payWithEIP712(
            o,
            buyerSig,
            q,
            bytes(""), //sellerSig
            bytes(""), // permit2612
            bytes("") // permit2
        );
        vm.stopPrank();
    }

    function test_payWithEIP712_RevertWith_SellerSigExpired() public {
        vm.prank(buyer);
        RecipientHandler.PriceQuote memory q = RecipientHandler.PriceQuote({
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
        bytes memory sellerSig = sign(quoteDigest, sellerPk);

        uint256 buyerNonce = handler.nextNonce(buyer);
        RecipientHandler.Order memory o = RecipientHandler.Order({
            buyer: buyer,
            payTo: address(handler),
            paymentToken: USDC,
            totalAmount: price,
            nonce: buyerNonce,
            quoteId: quoteId,
            serviceId: serviceId,
            deadline: nowTime + 10 days //Eusure Quote expire before Order
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

        vm.warp(nowTime + 2 days); //Expired
        vm.expectRevert(Errors.SigExpired.selector);
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

    function test_payWithEIP712_RevertWith_NotPayTo(address _payTo) public {
        vm.startPrank(buyer);
        RecipientHandler.PriceQuote memory q = RecipientHandler.PriceQuote({
            quoteId: quoteId,
            paymentToken: USDC,
            seller: seller,
            price: price,
            cost: cost,
            serviceId: serviceId,
            expiry: nowTime + 10 days
        });
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
        o.payTo = _payTo;
        vm.expectRevert(Errors.NotPayTo.selector);
        handler.payWithEIP712(o, bytes(""), q, bytes(""), bytes(""), bytes(""));
        vm.stopPrank();
    }

    function test_payWithEIP712_RevertWith_DuplicatedNonce() public {
        RecipientHandler.PriceQuote memory q = RecipientHandler.PriceQuote({
            quoteId: quoteId,
            paymentToken: USDC,
            seller: seller,
            price: price,
            cost: cost,
            serviceId: serviceId,
            expiry: nowTime + 10 days
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

        vm.prank(buyer);
        handler.payWithEIP712(o, buyerSig, q, sellerSig, bytes(""), bytes(""));

        uint256 current = handler.nextNonce(buyer); // = buyerNonce + 1
        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Nonces.InvalidAccountNonce.selector,
                buyer,
                current
            )
        );
        handler.payWithEIP712(o, buyerSig, q, sellerSig, bytes(""), bytes(""));
    }
}
