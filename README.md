# Recipient Handler Smart Contract

This repository contains the **RecipientHandler** smart contract.  
It enables seller quoting, buyer payments with EIP-712 signatures, commission handling, and secure withdrawals.

---

## ⚙️ Workflow Overview

### 1. Service Creation
- Platform calls:
  ```solidity
  createService(serviceId, seller)
Binds a service ID to a seller address.

2. Seller Quoting
Seller issues and signs a PriceQuote (EIP-712).

Seller can revoke or unrevoke quotes at any time.

3. Buyer Payment
Buyer signs an Order and calls:

solidity
复制代码
payWithEIP712(order, buyerSig, quote, sellerQuoteSig, permitData)
Contract verifies:

Buyer and seller signatures

Quote validity

Service binding (serviceId → seller)

Token allowance or permits (EIP-2612 / Permit2)

4. Settlement
Buyer transfers tokens to the contract.

Profit split:

Seller profit = (price - cost) * sellerRate / BPS

Commission = (price - cost) - sellerProfit

Commission is forwarded to distributionSC.

5. Withdrawal
Seller calls:

solidity
复制代码
claim(token, amount)
Withdraws accumulated profit in the chosen token.

📑 Data Structures
Order
solidity
复制代码
struct Order {
    address buyer;
    address payTo;
    address paymentToken;
    uint256 totalAmount;
    uint256 nonce;
    bytes32 quoteId;
    uint128 serviceId;
    uint64 deadline;
}
PriceQuote
solidity
复制代码
struct PriceQuote {
    bytes32 quoteId;
    address paymentToken;
    address seller;
    uint256 price;
    uint256 cost;
    uint128 serviceId;
    uint64 expiry;
}
🔒 Security Features
Replay Protection
Uses OpenZeppelin Nonces with _useCheckedNonce.

Reentrancy Guard
lock modifier prevents nested calls.

Pausable
Contract owner can pause/unpause in emergencies.

Access Control
Currently Ownable, but can migrate to AccessControl.

Strict Validation

Service ID must be registered.

Buyer and seller signatures must match.

Revoked quotes cannot be used.

Zero addresses and zero amounts are rejected.

📊 Parameters
sellerRate: percentage (in BPS) of net profit allocated to sellers.

BPS: constant = 10,000 (basis points).

distributionSC: external contract handling commission distribution.

🔄 Example Flow
Platform calls createService(101, sellerAddr).

Seller issues and signs PriceQuote.

Buyer signs Order and calls payWithEIP712(...).

Contract validates signatures, transfers funds.

Settlement

Seller profit credited.

Commission forwarded.

Seller calls claim(token, amount) to withdraw profit.

🚀 Development Notes
Written in Solidity ^0.8.20

Developed with Hardhat

Tested with Foundry

📝 To-Do / Future Improvements
Migrate Ownable → AccessControl with roles:

ADMIN_ROLE

SELLER_ROLE

Add optional referrer support (commission split).

Enhance distributionSC with flexible allocation logic.

