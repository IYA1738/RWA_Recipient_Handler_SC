# Recipient Handler Smart Contract

This repository contains the **RecipientHandler** smart contract.  
It enables seller quoting, buyer payments with EIP-712 signatures, commission handling, and secure withdrawals.  
Supports **Permit2** and **EIP-2612** for gasless approvals.

## 📖 Overview

- Buyers pay securely using **EIP-712 signed orders**.  
- Sellers issue **EIP-712 signed PriceQuotes** to define prices and costs.  
- The platform takes commission and forwards it to `distributionSC`.  
- Sellers can withdraw accumulated profits.

## 👥 Roles

- **Owner (Platform)**
  - Registers services: `serviceId → seller`
  - Sets `distributionSC`
  - Sets `sellerRate` (BPS)
  - Can `pause()` / `unpause()`

- **Seller**
  - Issues & signs `PriceQuote`
  - May revoke / unrevoke quotes
  - Withdraws profits via `claim(token, amount)`

- **Buyer**
  - Signs `Order` and calls `payWithEIP712(...)`

- **Distribution Contract**
  - Receives platform commission for further allocation (e.g., BBB, treasury, referrals)

## 📂 Structure

contracts/
├─ RecipientHandler.sol
├─ interfaces/
│ └─ IDistribution.sol
└─ libraries/
├─ Errors.sol
├─ Constants.sol
└─ PermitHelper.sol

css

## 📑 Data Structures

### Order
```solidity
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

struct PriceQuote {
    bytes32 quoteId;
    address paymentToken;
    address seller;
    uint256 price;
    uint256 cost;
    uint128 serviceId;
    uint64 expiry;
}
✍️ Signatures (EIP-712)
TypeHashes
solidity

bytes32 public constant PRICEQUOTE_TYPEHASH = keccak256(
  "PriceQuote(bytes32 quoteId,address paymentToken,address seller,uint256 price,uint256 cost,uint128 serviceId,uint64 expiry)"
);

bytes32 public constant ORDER_TYPEHASH = keccak256(
  "Order(address buyer,address payTo,address paymentToken,uint256 totalAmount,uint256 nonce,bytes32 quoteId,uint128 serviceId,uint64 deadline)"
);
Seller signs PriceQuote (ethers v6)
ts
const domain = {
  name: "RecipientHandler",
  version: "1",
  chainId,
  verifyingContract: recipientHandlerAddress,
};

const types = {
  PriceQuote: [
    { name: "quoteId", type: "bytes32" },
    { name: "paymentToken", type: "address" },
    { name: "seller", type: "address" },
    { name: "price", type: "uint256" },
    { name: "cost", type: "uint256" },
    { name: "serviceId", type: "uint128" },
    { name: "expiry", type: "uint64" },
  ],
};

const quote = {
  quoteId,
  paymentToken,
  seller,
  price: priceWei,
  cost: costWei,
  serviceId: 123,
  expiry: Math.floor(Date.now() / 1000) + 86400,
};

const sellerQuoteSig = await seller.signTypedData(domain, types, quote);
Buyer signs Order (ethers v6)

ts
const types = {
  Order: [
    { name: "buyer", type: "address" },
    { name: "payTo", type: "address" },
    { name: "paymentToken", type: "address" },
    { name: "totalAmount", type: "uint256" },
    { name: "nonce", type: "uint256" },
    { name: "quoteId", type: "bytes32" },
    { name: "serviceId", type: "uint128" },
    { name: "deadline", type: "uint64" },
  ],
};

const order = {
  buyer,
  payTo: recipientHandlerAddress,
  paymentToken,
  totalAmount: priceWei,
  nonce: await recipientHandler.nextNonce(buyer),
  quoteId,
  serviceId: 123,
  deadline: Math.floor(Date.now() / 1000) + 600,
};

const buyerSig = await buyer.signTypedData(domain, types, order);
⚙️ Workflow
1. Service Creation
Platform registers service and binds seller:

solidity

createService(serviceId, seller);
2. Seller Quoting
Seller issues and signs a PriceQuote off-chain.

Seller can revoke / unrevoke a quote on-chain:

solidity

revokeQuote(quote, sellerQuoteSig);
unrevokeQuote(quote, sellerQuoteSig);
3. Buyer Payment
Buyer signs an Order and calls:

solidity

payWithEIP712(order, buyerSig, quote, sellerQuoteSig, permit2612, permit2Data);
Contract verifies:

Buyer signature (EIP-712 + nonce)

Seller quote signature (EIP-712)

Quote not expired / not revoked

Seller bound to serviceId

Token authorization (Permit2 / EIP-2612 / allowance)

4. Settlement
Buyer transfers tokens to contract

Seller profit = (price - cost) * sellerRate / BPS

Commission = (price - cost) - sellerProfit

Commission sent to distributionSC

5. Withdrawal
Seller calls:

claim(token, amount);
Withdraws accumulated profit

🔒 Security
Replay protection: Nonces with _useCheckedNonce

Reentrancy guard: lock modifier

Pausable: pause() / unpause() by Owner

Strict validation:

Service must be active & registered

Seller from quote must match bound seller

Revoked quotes cannot be used

Zero address / zero amount checks

⚙️ Parameters
BPS = 10_000

sellerRate (in BPS): seller share of net profit

distributionSC: commission distribution contract

🚀 Development Notes
Solidity ^0.8.22

Dev with Hardhat

Test with Foundry

To avoid "stack too deep", enable viaIR:

solidity: {
  version: "0.8.22",
  settings: {
    optimizer: { enabled: true, runs: 200 },
    viaIR: true,
  }
}
🧭 Future Improvements
Migrate Ownable → AccessControl

Extend distributionSC with referral / split logic

Token whitelist and fee-on-transfer support

📜 License
MIT