// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "contracts/RecipientHandler.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
contract RecipientHandlerHarness is RecipientHandler {
    using ECDSA for bytes32;
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
        );assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000001,digest)}
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
        );assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000002,digest)}
        return digest.recover(sig) == q.seller;
    }
}
