📖 Overview

RecipientHandler is a settlement and distribution smart contract that connects Buyers, Sellers, and the Platform.
Key features:

Buyers pay securely using EIP-712 signed orders

Sellers issue EIP-712 signed PriceQuotes to define prices and costs

The platform automatically charges commission and distributes it via distributionSC

Sellers can safely withdraw their earnings

Supports Permit2 and EIP-2612 for gasless token approvals

👥 Roles

Owner (Platform)

Registers services (serviceId → seller)

Manages the distribution contract (distributionSC)

Configures seller revenue share (sellerRate)

Can pause/unpause the contract

Seller

Owns one or more serviceIds

Issues and signs PriceQuotes (with price, cost, expiry)

Can revoke/unrevoke quotes

Can withdraw accumulated profits

Buyer

Receives a seller’s PriceQuote

Creates and signs an Order (linked to quoteId)

Calls payWithEIP712 to complete payment

Distribution Contract

Receives platform commission for further allocation (e.g., BBB, treasury, referral program)

📂 Contract Structure
contracts/
 ├─ RecipientHandler.sol        // Main contract
 ├─ interfaces/
 │   └─ IDistribution.sol       // Distribution interface
 └─ libraries/
     ├─ Errors.sol              // Custom errors
     ├─ Constants.sol           // Constants
     └─ PermitHelper.sol        // Permit2 / EIP-2612 helpers

📦 Data Structures
Order (Buyer Order)
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

PriceQuote (Seller Quote)
struct PriceQuote {
    bytes32 quoteId;
    address paymentToken;
    address seller;
    uint256 price;
    uint256 cost;
    uint128 serviceId;
    uint64 expiry;
}

✍️ Signature Standards
Seller Quote Signature (EIP-712)

TypeHash

PRICEQUOTE_TYPEHASH =
  keccak256("PriceQuote(bytes32 quoteId,address paymentToken,address seller,uint256 price,uint256 cost,uint128 serviceId,uint64 expiry)");


Example (ethers.js v6)

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
  expiry: Math.floor(Date.now() / 1000) + 86400, // +1 day
};

const sellerQuoteSig = await seller.signTypedData(domain, types, quote);

Buyer Order Signature (EIP-712)

TypeHash

ORDER_TYPEHASH =
  keccak256("Order(address buyer,address payTo,address paymentToken,uint256 totalAmount,uint256 nonce,bytes32 quoteId,uint128 serviceId,uint64 deadline)");


Example

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
  deadline: Math.floor(Date.now() / 1000) + 600, // +10 minutes
};

const buyerSig = await buyer.signTypedData(domain, types, order);

⚡ Workflow

Service Registration

Platform calls createService(serviceId, seller)

Seller Quoting

Seller issues and signs PriceQuote

Can revoke/unrevoke quotes

Buyer Payment

Buyer signs Order and calls payWithEIP712(order, buyerSig, quote, sellerQuoteSig, permitData)

Contract verifies buyer and seller signatures, quote validity, service binding, and token authorization

Settlement

Buyer transfers tokens to the contract

Seller profit = (price - cost) * sellerRate / BPS

Commission = (price - cost) - sellerProfit → sent to distributionSC

Withdrawal

Seller calls claim(token, amount) to withdraw accumulated profit


🔒 Security

Replay protection: Nonces (_useCheckedNonce)

Reentrancy guard: lock modifier

Pausable: Owner can pause in emergencies

Access control: Currently Ownable (could migrate to AccessControl)

Strict checks: ServiceId binding, seller verification, signature validation

🚀 Future Improvements

Replace Ownable with AccessControl for more granular roles


📜 License: MIT