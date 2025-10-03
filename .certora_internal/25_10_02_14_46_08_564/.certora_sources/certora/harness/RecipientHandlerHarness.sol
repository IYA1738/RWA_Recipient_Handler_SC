// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "contracts/RecipientHandler.sol";

contract RecipientHandlerHarness is RecipientHandler {
    constructor(
        address distribution,
        uint256 rate
    ) RecipientHandler("RecipientHandler", "1", distribution, rate) {}

    function h_setDistributionSC(address d) external {
        distributionSC = d;
    }

    function h_setCommissionRate(uint256 r) external {
        require(r <= BPS && r > 0, "bad rate");
        commissionRate = r;
    }

    function h_bindService(uint128 serviceId, address seller) external {
        require(seller != address(0), "zero seller");
        require(serviceToSeller[serviceId] == address(0), "dup");
        serviceToSeller[serviceId] = seller;

        serviceActive[serviceId] = true;
    }

    function h_settle(
        address buyer,
        address paymentToken,
        address seller,
        uint128 serviceId,
        uint256 amount,
        uint256 cost
    ) external {
        _settle(buyer, paymentToken, seller, serviceId, amount, cost);
    }

    function h_payWithEIP712_minimal(
        address buyer,
        address token,
        address seller,
        uint128 serviceId,
        uint256 price,
        uint256 cost,
        uint64 deadline,
        bytes calldata sig,
        bytes calldata sellerSig,
        bytes calldata permit2612,
        bytes calldata permit2Data
    ) external {
        Order memory o = Order({
            buyer: buyer,
            payTo: address(this),
            paymentToken: token,
            totalAmount: price,
            nonce: nonces(buyer),
            quoteId: keccak256(
                abi.encode(buyer, token, seller, serviceId, price, cost)
            ),
            serviceId: serviceId,
            deadline: deadline
        });

        PriceQuote memory q = PriceQuote({
            quoteId: o.quoteId,
            paymentToken: token,
            seller: seller,
            price: price,
            cost: cost,
            serviceId: serviceId,
            expiry: deadline
        });

        payWithEIP712(o, sig, q, sellerSig, permit2612, permit2Data);
    }

    //check Sigs to simple process
    function h_checkOrderSig(
        Order calldata o,
        bytes calldata sig
    ) external view returns (bool) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
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
            )
        );
        return digest.recover(sig) == o.buyer;
    }

    function h_checkQuoteSig(
        PriceQuote calldata q,
        bytes calldata sig
    ) external view returns (bool) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
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
            )
        );
        return digest.recover(sig) == q.seller;
    }
}
