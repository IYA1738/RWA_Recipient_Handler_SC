
macro mkOrder(
  address buyer, address token, address payTo,
  uint128 serviceId, uint amount, uint nonce, uint64 deadline, bytes32 quoteId
) returns (RecipientHandlerHarness.Order memory) {
  RecipientHandlerHarness.Order({
    buyer: buyer,
    payTo: payTo,
    paymentToken: token,
    totalAmount: amount,
    nonce: nonce,
    quoteId: quoteId,
    serviceId: serviceId,
    deadline: deadline
  })
}

macro mkQuote(
  bytes32 quoteId, address token, address seller,
  uint price, uint cost, uint128 serviceId, uint64 expiry
) returns (RecipientHandlerHarness.PriceQuote memory) {
  RecipientHandlerHarness.PriceQuote({
    quoteId: quoteId,
    paymentToken: token,
    seller: seller,
    price: price,
    cost: cost,
    serviceId: serviceId,
    expiry: expiry
  })
}

rule BuyerInvalidSig_ShouldRevert(
  RecipientHandlerHarness handler,
  MockERC20 token,
  address buyer,
  address seller,
  uint128 serviceId,
  uint amount,
  uint cost,
  uint64 deadline,
  bytes sigBuyer,
  bytes sigSeller
){
  require buyer  != 0;
  require seller != 0;
  require amount > 0;
  require cost   > 0;
  require cost   < amount;

  handler.h_bindService(serviceId, seller);

  address payTo = address(handler);
  address paymentToken = address(token);
  bytes32 quoteId = keccak256(abi.encode(buyer, paymentToken, seller, serviceId, amount, cost));

  RecipientHandlerHarness.Order      memory o =
    mkOrder(buyer, paymentToken, payTo, serviceId, amount, handler.nonces(buyer), deadline, quoteId);
  RecipientHandlerHarness.PriceQuote memory q =
    mkQuote(quoteId, paymentToken, seller, amount, cost, serviceId, deadline);

  assume !handler.h_checkOrderSig(o, sigBuyer);
  assume  handler.h_checkQuoteSig(q, sigSeller);

  //Set a bigger amount to make sure enough allowance
  token.setAllowance(buyer, address(handler), amount);

  expect revert;
  handler.payWithEIP712(o, sigBuyer, q, sigSeller, "", "");
}

